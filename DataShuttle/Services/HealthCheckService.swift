import Foundation
import Darwin

/// Scans and validates symlinks created by DataShuttle
@MainActor
@Observable
final class HealthCheckService {
    
    struct SymlinkStatus: Identifiable, Sendable {
        let id = UUID()
        let originalPath: String
        let targetPath: String
        let folderName: String
        let isBroken: Bool
        let isTargetMounted: Bool
        let sizeBytes: Int64
        let volumeName: String
        
        var statusLabel: String {
            if isBroken && !isTargetMounted {
                return L10n.tr("Ổ phụ chưa kết nối")
            } else if isBroken {
                return L10n.tr("Symlink hỏng")
            }
            return L10n.tr("Hoạt động tốt")
        }
    }
    
    var results: [SymlinkStatus] = []
    var isScanning = false
    var lastScanDate: Date?
    
    var healthyCount: Int { results.filter { !$0.isBroken }.count }
    var brokenCount: Int { results.filter { $0.isBroken }.count }
    var unmountedCount: Int { results.filter { $0.isBroken && !$0.isTargetMounted }.count }
    
    private let fileManager = FileManager.default
    
    /// Scan all shuttled items for broken symlinks
    func scan(items: [ShuttleItem]) async {
        isScanning = true
        results = []
        
        // Capture item data for background processing
        struct ItemData: Sendable {
            let originalPath: String
            let destinationPath: String
            let folderName: String
            let sizeBytes: Int64
            let destinationVolume: String
        }
        
        let itemsData = items
            .filter { $0.status == .shuttled }
            .map { ItemData(
                originalPath: $0.originalPath,
                destinationPath: $0.destinationPath,
                folderName: $0.folderName,
                sizeBytes: $0.sizeBytes,
                destinationVolume: $0.destinationVolume
            )}
        
        // Run file I/O on background thread
        let scannedResults: [SymlinkStatus] = await Task.detached {
            let fm = FileManager.default
            var statuses: [SymlinkStatus] = []
            
            for item in itemsData {
                let sourceEntry = Self.fileSystemEntryInfo(at: item.originalPath)
                let targetExists = Self.fileSystemEntryInfo(at: item.destinationPath).exists
                let volumeMountPoint = Self.extractVolumeMountPoint(from: item.destinationPath)
                let isVolumeMounted = volumeMountPoint == "/" || fm.fileExists(atPath: volumeMountPoint)
                
                let isBroken = !sourceEntry.exists || !sourceEntry.isSymbolicLink || !targetExists
                
                statuses.append(SymlinkStatus(
                    originalPath: item.originalPath,
                    targetPath: item.destinationPath,
                    folderName: item.folderName,
                    isBroken: isBroken,
                    isTargetMounted: isVolumeMounted,
                    sizeBytes: item.sizeBytes,
                    volumeName: item.destinationVolume
                ))
            }
            
            return statuses
        }.value
        
        results = scannedResults
        lastScanDate = Date()
        isScanning = false
    }
    
    /// Attempt to fix a broken symlink by re-creating it
    func fixSymlink(for status: SymlinkStatus) throws {
        guard status.isBroken else { return }
        guard status.isTargetMounted else {
            throw FixError.volumeNotMounted
        }
        guard fileManager.fileExists(atPath: status.targetPath) else {
            throw FixError.targetNotFound
        }
        
        // Remove broken symlink or leftover
        if Self.fileSystemEntryInfo(at: status.originalPath).exists {
            try fileManager.removeItem(atPath: status.originalPath)
        }
        
        // Re-create symlink
        try fileManager.createSymbolicLink(
            atPath: status.originalPath,
            withDestinationPath: status.targetPath
        )
    }
    
    enum FixError: LocalizedError {
        case volumeNotMounted
        case targetNotFound
        
        var errorDescription: String? {
            switch self {
            case .volumeNotMounted: return L10n.tr("Ổ phụ chưa được kết nối. Hãy cắm ổ rồi thử lại.")
            case .targetNotFound: return L10n.tr("Thư mục đích không tồn tại.")
            }
        }
    }
    
    nonisolated private static func extractVolumeMountPoint(from path: String) -> String {
        let components = path.split(separator: "/")
        if components.count >= 2 && components[0] == "Volumes" {
            return "/Volumes/\(components[1])"
        }
        return "/"
    }
    
    nonisolated private static func fileSystemEntryInfo(at path: String) -> (exists: Bool, isSymbolicLink: Bool) {
        var fileInfo = stat()
        guard lstat(path, &fileInfo) == 0 else {
            return (exists: false, isSymbolicLink: false)
        }
        
        return (
            exists: true,
            isSymbolicLink: (fileInfo.st_mode & S_IFMT) == S_IFLNK
        )
    }
}
