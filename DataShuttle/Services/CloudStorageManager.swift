import Foundation

/// Detects cloud storage services installed on the system
@MainActor
@Observable
final class CloudStorageManager {
    
    struct CloudService: Identifiable, Sendable {
        enum ConnectionStatus: Sendable {
            case connected
            case syncFolderDetected
            case appDetected
            case permissionIssue
            case unavailable
        }
        
        let id: String
        let name: String
        let icon: String
        let localPath: String
        let isAvailable: Bool
        let usedBytes: Int64
        let color: String // For UI
        let doesSyncFolderExist: Bool
        let isDesktopAppInstalled: Bool
        let isSyncProcessRunning: Bool
        let isFolderReadable: Bool
        let status: ConnectionStatus
        let statusTitle: String
        let statusDetail: String
        let statusSymbol: String
    }
    
    private struct KnownCloudService: Sendable {
        let id: String
        let name: String
        let icon: String
        let color: String
        let fixedPaths: [String]
        let folderPrefixes: [String]
        let appCandidatePaths: [String]
        let processHints: [String]
        let isSystemManaged: Bool
    }
    
    var detectedServices: [CloudService] = []
    var isScanning = false
    
    private let fileManager: FileManager
    private let homeDirectoryPath: String
    private let processListProvider: @Sendable () -> [String]
    private let applicationPathResolver: ([String]) -> String?
    
    init(
        fileManager: FileManager = .default,
        homeDirectoryPath: String = "/Users/\(NSUserName())",
        processListProvider: (@Sendable () -> [String])? = nil,
        applicationPathResolver: (([String]) -> String?)? = nil
    ) {
        self.fileManager = fileManager
        self.homeDirectoryPath = homeDirectoryPath
        if let processListProvider {
            self.processListProvider = processListProvider
        } else {
            self.processListProvider = { CloudStorageManager.runningProcesses() }
        }
        self.applicationPathResolver = applicationPathResolver ?? { candidates in
            for path in candidates {
                var isDir: ObjCBool = false
                if fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                    return path
                }
            }
            return nil
        }
    }
    
    /// Known cloud storage local paths on macOS
    private var knownServices: [KnownCloudService] {
        return [
            KnownCloudService(
                id: "icloud",
                name: "iCloud Drive",
                icon: "icloud.fill",
                color: "blue",
                fixedPaths: [
                    homeDirectoryPath + "/Library/Mobile Documents/com~apple~CloudDocs",
                    homeDirectoryPath + "/iCloud Drive"
                ],
                folderPrefixes: ["iCloudDrive", "iCloud", "CloudDocs"],
                appCandidatePaths: [],
                processHints: [" bird", "cloudd", "iCloudDrive"],
                isSystemManaged: true
            ),
            KnownCloudService(
                id: "googledrive",
                name: "Google Drive",
                icon: "externaldrive.fill.badge.icloud",
                color: "green",
                fixedPaths: [
                    homeDirectoryPath + "/Google Drive",
                    homeDirectoryPath + "/My Drive",
                    homeDirectoryPath + "/Library/CloudStorage/GoogleDrive"
                ],
                folderPrefixes: ["GoogleDrive", "Google Drive", "My Drive"],
                appCandidatePaths: [
                    "/Applications/Google Drive.app",
                    homeDirectoryPath + "/Applications/Google Drive.app"
                ],
                processHints: ["Google Drive", "GoogleDrive", "GoogleDriveFS", "webdavfs_agent"],
                isSystemManaged: false
            ),
            KnownCloudService(
                id: "dropbox",
                name: "Dropbox",
                icon: "shippingbox.fill",
                color: "cyan",
                fixedPaths: [
                    homeDirectoryPath + "/Dropbox",
                    homeDirectoryPath + "/Library/CloudStorage/Dropbox"
                ],
                folderPrefixes: ["Dropbox"],
                appCandidatePaths: [
                    "/Applications/Dropbox.app",
                    homeDirectoryPath + "/Applications/Dropbox.app"
                ],
                processHints: ["Dropbox"],
                isSystemManaged: false
            ),
            KnownCloudService(
                id: "onedrive",
                name: "OneDrive",
                icon: "cloud.fill",
                color: "purple",
                fixedPaths: [
                    homeDirectoryPath + "/OneDrive",
                    homeDirectoryPath + "/Library/CloudStorage/OneDrive-Personal"
                ],
                folderPrefixes: ["OneDrive"],
                appCandidatePaths: [
                    "/Applications/OneDrive.app",
                    homeDirectoryPath + "/Applications/OneDrive.app"
                ],
                processHints: ["OneDrive"],
                isSystemManaged: false
            )
        ]
    }
    
    /// Detect all cloud storage folders by scanning CloudStorage and known paths.
    /// Runs heavy folder size calculations on background threads.
    func detectCloudServices() async {
        isScanning = true
        defer { isScanning = false }
        
        var discoveredKnownPaths: [String: String] = [:]
        var unknownFolders: [(name: String, path: String)] = []
        let runningProcesses = processListProvider().map { $0.lowercased() }
        
        // Method 1: Scan ~/Library/CloudStorage (macOS 12+)
        let cloudStoragePath = homeDirectoryPath + "/Library/CloudStorage"
        if let contents = try? fileManager.contentsOfDirectory(atPath: cloudStoragePath).sorted() {
            for folder in contents {
                let fullPath = cloudStoragePath + "/" + folder
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue else { continue }
                
                if let matched = matchCloudFolder(name: folder) {
                    discoveredKnownPaths[matched.id] = fullPath
                } else {
                    unknownFolders.append((name: folder, path: fullPath))
                }
            }
        }
        
        var services: [CloudService] = []
        
        for service in knownServices {
            let availablePath = discoveredKnownPaths[service.id] ?? firstExistingPath(in: service.fixedPaths)
            let fallbackPath = availablePath ?? service.fixedPaths.first ?? ""
            let folderPath = availablePath ?? fallbackPath
            let folderState = folderState(at: folderPath)
            let appPath = applicationPathResolver(service.appCandidatePaths)
            let processRunning = containsRunningProcess(runningProcesses, hints: service.processHints)
            let isDesktopAppInstalled = service.isSystemManaged || appPath != nil
            let status = makeStatus(
                service: service,
                folderExists: folderState.exists,
                folderReadable: folderState.isReadable,
                isDesktopAppInstalled: isDesktopAppInstalled,
                isProcessRunning: processRunning
            )
            let syncReachable = folderState.exists && folderState.isReadable
            
            services.append(
                    CloudService(
                        id: service.id,
                        name: service.name,
                        icon: service.icon,
                        localPath: folderPath,
                        isAvailable: syncReachable,
                        usedBytes: syncReachable ? await folderSize(at: folderPath) : 0,
                        color: service.color,
                        doesSyncFolderExist: folderState.exists,
                        isDesktopAppInstalled: isDesktopAppInstalled,
                        isSyncProcessRunning: processRunning,
                        isFolderReadable: folderState.isReadable,
                        status: status.status,
                        statusTitle: status.title,
                    statusDetail: status.detail,
                    statusSymbol: status.symbol
                )
            )
        }
        
        let extras: [CloudService] = await Task.detached {
            let fileManager = FileManager.default
            return unknownFolders.map { folder in
                let isReadable = fileManager.isReadableFile(atPath: folder.path)
                return CloudService(
                    id: folder.path,
                    name: folder.name.replacingOccurrences(of: "-", with: " "),
                    icon: "cloud.fill",
                    localPath: folder.path,
                    isAvailable: isReadable,
                    usedBytes: isReadable ? DiskAnalyzer.folderSize(at: folder.path) : 0,
                    color: "gray",
                    doesSyncFolderExist: true,
                    isDesktopAppInstalled: false,
                    isSyncProcessRunning: false,
                    isFolderReadable: isReadable,
                    status: isReadable ? .connected : .permissionIssue,
                    statusTitle: isReadable ? "Đã phát hiện thư mục sync" : "Không đọc được thư mục sync",
                    statusDetail: isReadable ? "Đã phát hiện dịch vụ cloud chưa định danh, có thể dùng làm đích shuttle." : "Có thư mục cloud nhưng app không có quyền đọc.",
                    statusSymbol: isReadable ? "checkmark.icloud.fill" : "exclamationmark.triangle.fill"
                )
            }
        }.value
        
        detectedServices = services + extras.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    private func matchCloudFolder(name: String) -> KnownCloudService? {
        let lower = name.lowercased()
        
        for service in knownServices {
            let matchesID = lower.contains(service.id.lowercased())
            let matchesName = lower.contains(service.name.lowercased().replacingOccurrences(of: " ", with: ""))
            let matchesPrefix = service.folderPrefixes.contains {
                lower.hasPrefix($0.lowercased().replacingOccurrences(of: " ", with: ""))
            }
            
            if matchesID || matchesName || matchesPrefix {
                return service
            }
        }
        return nil
    }
    
    private func firstExistingPath(in paths: [String]) -> String? {
        for path in paths {
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                return path
            }
        }
        return nil
    }
    
    private func folderSize(at path: String) async -> Int64 {
        await Task.detached {
            DiskAnalyzer.folderSize(at: path)
        }.value
    }
    
    private func folderState(at path: String) -> (exists: Bool, isReadable: Bool) {
        guard !path.isEmpty else {
            return (exists: false, isReadable: false)
        }
        
        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return (exists: false, isReadable: false)
        }
        
        guard fileManager.isReadableFile(atPath: path) else {
            return (exists: true, isReadable: false)
        }
        
        do {
            _ = try fileManager.contentsOfDirectory(atPath: path)
            return (exists: true, isReadable: true)
        } catch {
            return (exists: true, isReadable: false)
        }
    }
    
    private func containsRunningProcess(_ processes: [String], hints: [String]) -> Bool {
        let normalizedHints = hints.map { $0.lowercased() }
        return processes.contains { process in
            normalizedHints.contains { hint in process.contains(hint) }
        }
    }
    
    private func makeStatus(
        service: KnownCloudService,
        folderExists: Bool,
        folderReadable: Bool,
        isDesktopAppInstalled: Bool,
        isProcessRunning: Bool
    ) -> (status: CloudService.ConnectionStatus, title: String, detail: String, symbol: String) {
        if folderExists && !folderReadable {
            return (
                .permissionIssue,
                "Có thư mục sync nhưng không đọc được",
                "DataShuttle thấy thư mục local của \(service.name), nhưng chưa có quyền truy cập hoặc thư mục đang lỗi.",
                "exclamationmark.triangle.fill"
            )
        }
        
        if folderReadable && (isProcessRunning || service.isSystemManaged) {
            return (
                .connected,
                "Đã kết nối cục bộ",
                "Phát hiện thư mục sync local và tiến trình đồng bộ của \(service.name).",
                "checkmark.icloud.fill"
            )
        }
        
        if folderReadable {
            return (
                .syncFolderDetected,
                "Có thư mục sync local",
                "Phát hiện thư mục sync local của \(service.name), nhưng chưa thấy tiến trình đồng bộ đang chạy.",
                "folder.badge.questionmark"
            )
        }
        
        if isDesktopAppInstalled || isProcessRunning {
            return (
                .appDetected,
                "Có app nhưng chưa thấy thư mục sync",
                "Đã phát hiện ứng dụng hoặc tiến trình của \(service.name), nhưng chưa thấy thư mục sync local khả dụng.",
                "app.badge.checkmark"
            )
        }
        
        return (
            .unavailable,
            "Chưa phát hiện trên máy",
            "Chưa thấy ứng dụng, tiến trình nền hoặc thư mục sync local của \(service.name).",
            "icloud.slash"
        )
    }
    
    nonisolated private static func runningProcesses() -> [String] {
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "command="]
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                return []
            }
            
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(decoding: data, as: UTF8.self)
                .split(separator: "\n")
                .map(String.init)
        } catch {
            return []
        }
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
    
    /// Evict local copy to free up space (keep on cloud)
    func evictItem(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        try fileManager.evictUbiquitousItem(at: url)
    }
    
    /// Start downloading item to keep it offline locally
    func downloadItem(at path: String) throws {
        let url = URL(fileURLWithPath: path)
        try fileManager.startDownloadingUbiquitousItem(at: url)
    }
}
