import Foundation

/// Detects cloud storage services installed on the system
@MainActor
@Observable
class CloudStorageManager {
    
    struct CloudService: Identifiable, Sendable {
        let id: String
        let name: String
        let icon: String
        let localPath: String
        let isAvailable: Bool
        let usedBytes: Int64
        let color: String // For UI
    }
    
    var detectedServices: [CloudService] = []
    var isScanning = false
    
    private let fileManager = FileManager.default
    
    /// Known cloud storage local paths on macOS
    private var knownServices: [(id: String, name: String, icon: String, paths: [String], color: String)] {
        let home = NSHomeDirectory()
        return [
            (
                id: "icloud",
                name: "iCloud Drive",
                icon: "icloud.fill",
                paths: [
                    home + "/Library/Mobile Documents/com~apple~CloudDocs",
                    home + "/iCloud Drive"
                ],
                color: "blue"
            ),
            (
                id: "googledrive",
                name: "Google Drive",
                icon: "externaldrive.fill.badge.icloud",
                paths: [
                    home + "/Google Drive",
                    home + "/My Drive",
                    home + "/Library/CloudStorage/GoogleDrive" // Google Drive for Desktop
                ],
                color: "green"
            ),
            (
                id: "dropbox",
                name: "Dropbox",
                icon: "shippingbox.fill",
                paths: [
                    home + "/Dropbox"
                ],
                color: "cyan"
            ),
            (
                id: "onedrive",
                name: "OneDrive",
                icon: "cloud.fill",
                paths: [
                    home + "/OneDrive",
                    home + "/Library/CloudStorage/OneDrive-Personal"
                ],
                color: "purple"
            )
        ]
    }
    
    /// Detect all cloud storage folders by scanning CloudStorage and known paths.
    /// Runs heavy folder size calculations on background threads.
    func detectCloudServices() async {
        isScanning = true
        detectedServices = []
        
        // Collect paths to analyze first (fast, filesystem metadata only)
        var discoveredFolders: [(id: String, name: String, icon: String, path: String, color: String)] = []
        
        // Method 1: Scan ~/Library/CloudStorage (macOS 12+)
        let cloudStoragePath = NSHomeDirectory() + "/Library/CloudStorage"
        if let contents = try? fileManager.contentsOfDirectory(atPath: cloudStoragePath) {
            for folder in contents {
                let fullPath = cloudStoragePath + "/" + folder
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else { continue }
                
                // Try to match to known service
                if let matched = matchCloudFolder(name: folder) {
                    discoveredFolders.append((id: matched.id, name: matched.name, icon: matched.icon, path: fullPath, color: matched.color))
                } else {
                    // Unknown cloud service
                    discoveredFolders.append((
                        id: folder,
                        name: folder.replacingOccurrences(of: "-", with: " "),
                        icon: "cloud.fill",
                        path: fullPath,
                        color: "gray"
                    ))
                }
            }
        }
        
        // Method 2: Check known paths for any not yet found
        let discoveredIds = Set(discoveredFolders.map { $0.id })
        for service in knownServices {
            guard !discoveredIds.contains(service.id) else { continue }
            
            for path in service.paths {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                    discoveredFolders.append((id: service.id, name: service.name, icon: service.icon, path: path, color: service.color))
                    break
                }
            }
        }
        
        // Calculate folder sizes on background to avoid blocking UI
        let folders = discoveredFolders
        let results: [CloudService] = await Task.detached {
            folders.map { folder in
                let size = DiskAnalyzer.folderSize(at: folder.path)
                return CloudService(
                    id: folder.id,
                    name: folder.name,
                    icon: folder.icon,
                    localPath: folder.path,
                    isAvailable: true,
                    usedBytes: size,
                    color: folder.color
                )
            }
        }.value
        
        detectedServices = results
        isScanning = false
    }
    
    private func matchCloudFolder(name: String) -> (id: String, name: String, icon: String, color: String)? {
        let lower = name.lowercased()
        
        for service in knownServices {
            if lower.contains(service.id.lowercased()) ||
               lower.contains(service.name.lowercased().replacingOccurrences(of: " ", with: "")) {
                return (id: service.id, name: service.name, icon: service.icon, color: service.color)
            }
        }
        return nil
    }
    
    /// Analyze contents of a cloud service to find what's taking space.
    /// Heavy I/O is dispatched to background.
    func analyzeCloudContents(at path: String) async -> [DiskAnalyzer.FolderAnalysis] {
        let analysisPath = path
        let results: [DiskAnalyzer.FolderAnalysis] = await Task.detached {
            let fm = FileManager.default
            let url = URL(fileURLWithPath: analysisPath)
            var items: [DiskAnalyzer.FolderAnalysis] = []
            
            do {
                let contents = try fm.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey, .fileSizeKey, .isRegularFileKey],
                    options: []
                )
                
                for itemURL in contents {
                    let values = try itemURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey, .fileSizeKey, .isRegularFileKey])
                    let isDir = values.isDirectory ?? false
                    let isSymlink = values.isSymbolicLink ?? false
                    var symlinkTarget: String? = nil
                    
                    if isSymlink {
                        symlinkTarget = try? fm.destinationOfSymbolicLink(atPath: itemURL.path)
                    }
                    
                    let size: Int64
                    let fileCount: Int
                    if isDir {
                        size = DiskAnalyzer.folderSize(at: itemURL.path)
                        fileCount = DiskAnalyzer.folderFileCount(at: itemURL.path)
                    } else {
                        size = Int64(values.fileSize ?? 0)
                        fileCount = 1
                    }
                    
                    guard size > 0 else { continue }
                    
                    items.append(DiskAnalyzer.FolderAnalysis(
                        path: itemURL.path,
                        name: itemURL.lastPathComponent,
                        sizeBytes: size,
                        fileCount: fileCount,
                        lastModified: values.contentModificationDate,
                        isSymlink: isSymlink,
                        symlinkTarget: symlinkTarget
                    ))
                }
            } catch {
                print("Error analyzing cloud path \(analysisPath): \(error)")
            }
            
            return items.sorted { $0.sizeBytes > $1.sizeBytes }
        }.value
        
        return results
    }
    
    /// Delete an item from cloud storage (permanent delete)
    func deleteItem(at path: String) throws {
        try fileManager.removeItem(atPath: path)
    }
}

