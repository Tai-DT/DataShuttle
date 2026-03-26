import Foundation

/// Analyzes disk usage for directories.
/// This is a stateless value-type utility — safe to use from any thread/actor context.
struct DiskAnalyzer: Sendable {
    
    struct FolderAnalysis: Identifiable, Sendable {
        let id = UUID()
        let path: String
        let name: String
        let sizeBytes: Int64
        let fileCount: Int
        let lastModified: Date?
        let isSymlink: Bool
        let symlinkTarget: String?
        
        var isLargeFolder: Bool {
            sizeBytes > 500_000_000 // > 500MB
        }
    }
    
    /// Analyze top-level folders in a directory (runs on background thread)
    nonisolated func analyzeFolders(at path: String, showHidden: Bool = false) async -> [FolderAnalysis] {
        let analysisPath = path
        let showHiddenFiles = showHidden
        
        return await Task.detached {
            let fm = FileManager.default
            let url = URL(fileURLWithPath: analysisPath)
            var results: [FolderAnalysis] = []
            
            do {
                let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles ? [] : [.skipsHiddenFiles]
                let contents = try fm.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey],
                    options: options
                )
                
                for itemURL in contents {
                    let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey])
                    
                    guard resourceValues.isDirectory == true else { continue }
                    
                    let isSymlink = resourceValues.isSymbolicLink ?? false
                    var symlinkTarget: String? = nil
                    
                    if isSymlink {
                        symlinkTarget = try? fm.destinationOfSymbolicLink(atPath: itemURL.path)
                    }
                    
                    let size = DiskAnalyzer.folderSize(at: itemURL.path)
                    let fileCount = DiskAnalyzer.folderFileCount(at: itemURL.path)
                    
                    let analysis = FolderAnalysis(
                        path: itemURL.path,
                        name: itemURL.lastPathComponent,
                        sizeBytes: size,
                        fileCount: fileCount,
                        lastModified: resourceValues.contentModificationDate,
                        isSymlink: isSymlink,
                        symlinkTarget: symlinkTarget
                    )
                    
                    results.append(analysis)
                }
            } catch {
                print("Error analyzing directory \(analysisPath): \(error)")
            }
            
            return results.sorted { $0.sizeBytes > $1.sizeBytes }
        }.value
    }
    
    /// Calculate total size of a directory or file
    nonisolated static func folderSize(at path: String) -> Int64 {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)
        
        if let attrs = try? fm.attributesOfItem(atPath: path),
           let type = attrs[.type] as? FileAttributeType,
           type == .typeRegular {
            return (attrs[.size] as? Int64) ?? 0
        }
        
        var totalSize: Int64 = 0
        
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                if resourceValues.isRegularFile == true {
                    totalSize += Int64(resourceValues.fileSize ?? 0)
                }
            } catch {
                continue
            }
        }
        
        return totalSize
    }
    
    /// Count files in a directory
    nonisolated static func folderFileCount(at path: String) -> Int {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: path)
        var count = 0
        
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: nil
        ) else { return 0 }
        
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
               values.isRegularFile == true {
                count += 1
            }
        }
        
        return count
    }
}

