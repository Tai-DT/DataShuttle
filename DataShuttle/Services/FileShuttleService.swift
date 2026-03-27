import Foundation
import SwiftData

/// Core service for moving directories between drives with symlink
@MainActor
@Observable
class FileShuttleService {
    
    var activeJobs: [TransferJob] = []
    
    private let fileManager = FileManager.default
    
    enum ShuttleError: LocalizedError, Sendable {
        case sourceNotFound
        case destinationExists
        case insufficientSpace
        case symlinkFailed
        case copyFailed(String)
        case verifyFailed
        case transferCancelled
        case restoreFailed(String)
        case permissionDenied
        case alreadySymlink
        
        var errorDescription: String? {
            switch self {
            case .sourceNotFound: return L10n.tr("Thư mục nguồn không tồn tại")
            case .destinationExists: return L10n.tr("Thư mục đích đã tồn tại")
            case .insufficientSpace: return L10n.tr("Không đủ dung lượng ổ đích")
            case .symlinkFailed: return L10n.tr("Không thể tạo symlink")
            case .copyFailed(let msg): return L10n.formatted("Lỗi copy: %@", msg)
            case .restoreFailed(let msg): return L10n.formatted("Lỗi khôi phục: %@", msg)
            case .permissionDenied: return L10n.tr("Không có quyền truy cập")
            case .alreadySymlink: return L10n.tr("Thư mục này đã là symlink")
            case .verifyFailed: return L10n.tr("Dữ liệu đích không khớp với nguồn — hủy xóa để bảo vệ dữ liệu")
            case .transferCancelled: return L10n.tr("Đã hủy chuyển")
            }
        }
    }
    
    // MARK: - File-by-file copy with progress (nonisolated for background I/O)
    
    /// Copy a directory or file with real progress tracking.
    /// Runs off main actor to avoid blocking UI.
    nonisolated private func copyWithProgress(
        from sourceURL: URL,
        to destinationURL: URL,
        job: TransferJob,
        onProgress: @MainActor @Sendable @escaping (TransferJob) -> Void
    ) throws {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: sourceURL.path, isDirectory: &isDir) else { return }
        
        if isDir.boolValue {
            // Create the destination directory
            try fm.createDirectory(
                at: destinationURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Enumerate all items
            guard let enumerator = fm.enumerator(
                at: sourceURL,
                includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .fileSizeKey],
                options: [],
                errorHandler: nil
            ) else { return }
            
            for case let itemURL as URL in enumerator {
                let relativePath = itemURL.path.replacingOccurrences(of: sourceURL.path + "/", with: "")
                let destItemURL = destinationURL.appendingPathComponent(relativePath)
                
                let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .isRegularFileKey])
                
                if resourceValues.isDirectory == true {
                    // Create subdirectory
                    try fm.createDirectory(
                        at: destItemURL,
                        withIntermediateDirectories: true,
                        attributes: nil
                    )
                } else {
                    // Create parent directory if needed
                    let parentDir = destItemURL.deletingLastPathComponent()
                    if !fm.fileExists(atPath: parentDir.path) {
                        try fm.createDirectory(
                            at: parentDir,
                            withIntermediateDirectories: true,
                            attributes: nil
                        )
                    }
                    
                    // Check cancel — read on main thread since @Observable
                    let cancelled = DispatchQueue.main.sync { job.isCancelled }
                    if cancelled { throw ShuttleError.transferCancelled }
                    
                    // Copy file
                    try fm.copyItem(at: itemURL, to: destItemURL)
                    
                    // Update progress — write on main thread since @Observable
                    let fileSize = Int64(resourceValues.fileSize ?? 0)
                    let relPath = relativePath
                    DispatchQueue.main.async {
                        job.transferredBytes += fileSize
                        job.currentFile = relPath
                        Task { @MainActor in
                            onProgress(job)
                        }
                    }
                }
            }
        } else {
            // It's a single file
            let parentDir = destinationURL.deletingLastPathComponent()
            if !fm.fileExists(atPath: parentDir.path) {
                try fm.createDirectory(
                    at: parentDir,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            }
            try fm.copyItem(at: sourceURL, to: destinationURL)
            
            let attrs = try fm.attributesOfItem(atPath: sourceURL.path)
            let fileSize = (attrs[.size] as? Int64) ?? 0
            let fileName = destinationURL.lastPathComponent
            DispatchQueue.main.async {
                job.transferredBytes += fileSize
                job.currentFile = fileName
                Task { @MainActor in
                    onProgress(job)
                }
            }
        }
    }
    
    // MARK: - Verify & Stats (nonisolated for background I/O)
    
    /// Verify copy integrity by comparing file count and total size
    nonisolated private func verifyIntegrity(source: URL, destination: URL) -> Bool {
        let sourceStats = directoryStats(at: source)
        let destStats = directoryStats(at: destination)
        return sourceStats.fileCount == destStats.fileCount && sourceStats.totalSize == destStats.totalSize
    }
    
    /// Get file count and total size of a directory
    nonisolated private func directoryStats(at url: URL) -> (fileCount: Int, totalSize: Int64) {
        let fm = FileManager.default
        var count = 0
        var size: Int64 = 0
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [],
            errorHandler: nil
        ) else { return (0, 0) }
        
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
               values.isRegularFile == true {
                count += 1
                size += Int64(values.fileSize ?? 0)
            }
        }
        return (count, size)
    }
    
    // MARK: - Shuttle (Main → External)
    
    /// Shuttle a directory from primary to secondary drive
    /// Heavy I/O is dispatched to background; UI state updates on MainActor.
    func shuttle(
        sourcePath: String,
        destinationBasePath: String,
        onProgress: @MainActor @Sendable @escaping (TransferJob) -> Void
    ) async throws -> ShuttleItem {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let folderName = sourceURL.lastPathComponent
        let destinationURL = URL(fileURLWithPath: destinationBasePath).appendingPathComponent(folderName)
        
        // Validations
        guard fileManager.fileExists(atPath: sourcePath) else {
            throw ShuttleError.sourceNotFound
        }
        
        let attrs = try? fileManager.attributesOfItem(atPath: sourcePath)
        if let fileType = attrs?[.type] as? FileAttributeType, fileType == .typeSymbolicLink {
            throw ShuttleError.alreadySymlink
        }
        
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw ShuttleError.destinationExists
        }
        
        // Check available space on destination (background to avoid UI freeze)
        let src = sourcePath
        let totalBytes = await Task.detached {
            DiskAnalyzer.folderSize(at: src)
        }.value
        
        let destVolumeURL = URL(fileURLWithPath: destinationBasePath)
        if let destValues = try? destVolumeURL.resourceValues(forKeys: [.volumeAvailableCapacityKey]) {
            let available = Int64(destValues.volumeAvailableCapacity ?? 0)
            if available < totalBytes {
                throw ShuttleError.insufficientSpace
            }
        }
        
        // Create transfer job
        let job = TransferJob(
            sourcePath: sourcePath,
            destinationPath: destinationURL.path,
            folderName: folderName,
            totalBytes: totalBytes
        )
        activeJobs.append(job)
        
        do {
            // Step 1: Ensure destination base exists
            try fileManager.createDirectory(
                at: URL(fileURLWithPath: destinationBasePath),
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Step 2: Copy with progress on background
            job.status = .inProgress
            job.statusDetail = L10n.tr("Đang sao chép file...")
            onProgress(job)
            
            let srcURL = sourceURL
            let dstURL = destinationURL
            try await Task.detached { [self] in
                try self.copyWithProgress(
                    from: srcURL,
                    to: dstURL,
                    job: job,
                    onProgress: onProgress
                )
            }.value
            
            // Step 3: Verify integrity on background
            job.statusDetail = L10n.tr("Đang kiểm tra toàn vẹn dữ liệu...")
            onProgress(job)
            let isValid = await Task.detached { [self] in
                self.verifyIntegrity(source: srcURL, destination: dstURL)
            }.value
            guard isValid else {
                throw ShuttleError.verifyFailed
            }
            
            // Step 4: Remove original
            job.statusDetail = L10n.tr("Đang xóa thư mục gốc...")
            onProgress(job)
            try fileManager.removeItem(at: sourceURL)
            
            // Step 5: Create symlink
            job.status = .creatingSymlink
            job.statusDetail = L10n.tr("Đang tạo symlink...")
            onProgress(job)
            
            try fileManager.createSymbolicLink(
                atPath: sourcePath,
                withDestinationPath: destinationURL.path
            )
            
            // Done
            job.status = .completed
            job.statusDetail = L10n.tr("Hoàn thành!")
            job.currentFile = nil
            onProgress(job)
            
            // Determine volume name from path
            let volumeName = extractVolumeName(from: destinationBasePath)
            
            return ShuttleItem(
                originalPath: sourcePath,
                destinationPath: destinationURL.path,
                folderName: folderName,
                sizeBytes: totalBytes,
                destinationVolume: volumeName
            )
            
        } catch let error as ShuttleError {
            job.status = .failed
            job.errorMessage = error.localizedDescription
            onProgress(job)
            throw error
        } catch {
            job.status = .failed
            job.errorMessage = error.localizedDescription
            onProgress(job)
            throw ShuttleError.copyFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Restore (External → Main, undo shuttle)
    
    func restore(
        item: ShuttleItem,
        onProgress: @MainActor @Sendable @escaping (TransferJob) -> Void
    ) async throws {
        let originalURL = URL(fileURLWithPath: item.originalPath)
        let destinationURL = URL(fileURLWithPath: item.destinationPath)
        
        guard fileManager.fileExists(atPath: item.destinationPath) else {
            throw ShuttleError.sourceNotFound
        }
        
        let job = TransferJob(
            sourcePath: item.destinationPath,
            destinationPath: item.originalPath,
            folderName: item.folderName,
            totalBytes: item.sizeBytes,
            isRestore: true
        )
        activeJobs.append(job)
        
        do {
            // Remove symlink
            job.status = .inProgress
            job.statusDetail = L10n.tr("Đang xóa symlink...")
            onProgress(job)
            
            if fileManager.fileExists(atPath: item.originalPath) {
                try fileManager.removeItem(at: originalURL)
            }
            
            // Copy back with progress on background
            job.statusDetail = L10n.tr("Đang sao chép về ổ chính...")
            onProgress(job)
            
            let srcURL = destinationURL
            let dstURL = originalURL
            try await Task.detached { [self] in
                try self.copyWithProgress(
                    from: srcURL,
                    to: dstURL,
                    job: job,
                    onProgress: onProgress
                )
            }.value
            
            // Verify on background
            job.statusDetail = L10n.tr("Đang kiểm tra toàn vẹn...")
            onProgress(job)
            let isValid = await Task.detached { [self] in
                self.verifyIntegrity(source: srcURL, destination: dstURL)
            }.value
            guard isValid else {
                throw ShuttleError.verifyFailed
            }
            
            // Remove source on external
            job.statusDetail = L10n.tr("Đang dọn dẹp ổ phụ...")
            onProgress(job)
            try fileManager.removeItem(at: destinationURL)
            
            job.status = .completed
            job.statusDetail = L10n.tr("Hoàn thành!")
            job.currentFile = nil
            onProgress(job)
            
            item.status = .restored
            
        } catch {
            job.status = .failed
            job.errorMessage = error.localizedDescription
            onProgress(job)
            throw ShuttleError.restoreFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Import (External → Main, new)
    
    func importToMain(
        sourcePath: String,
        destinationPath: String,
        deleteSource: Bool,
        createSymlink: Bool = false,
        onProgress: @MainActor @Sendable @escaping (TransferJob) -> Void
    ) async throws {
        let sourceURL = URL(fileURLWithPath: sourcePath)
        let folderName = sourceURL.lastPathComponent
        let destinationURL = URL(fileURLWithPath: destinationPath).appendingPathComponent(folderName)
        
        guard fileManager.fileExists(atPath: sourcePath) else {
            throw ShuttleError.sourceNotFound
        }
        
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw ShuttleError.destinationExists
        }
        
        let src = sourcePath
        let totalBytes = await Task.detached {
            DiskAnalyzer.folderSize(at: src)
        }.value
        
        let job = TransferJob(
            sourcePath: sourcePath,
            destinationPath: destinationURL.path,
            folderName: folderName,
            totalBytes: totalBytes,
            isRestore: false
        )
        activeJobs.append(job)
        
        do {
            try fileManager.createDirectory(
                at: URL(fileURLWithPath: destinationPath),
                withIntermediateDirectories: true,
                attributes: nil
            )
            
            // Copy with progress on background
            job.status = .inProgress
            job.statusDetail = L10n.tr("Đang sao chép về ổ chính...")
            onProgress(job)
            
            let srcURL = sourceURL
            let dstURL = destinationURL
            try await Task.detached { [self] in
                try self.copyWithProgress(
                    from: srcURL,
                    to: dstURL,
                    job: job,
                    onProgress: onProgress
                )
            }.value
            
            if deleteSource {
                // Verify on background
                job.statusDetail = L10n.tr("Đang kiểm tra toàn vẹn...")
                onProgress(job)
                let isValid = await Task.detached { [self] in
                    self.verifyIntegrity(source: srcURL, destination: dstURL)
                }.value
                guard isValid else {
                    throw ShuttleError.verifyFailed
                }
                
                job.statusDetail = L10n.tr("Đang xóa nguồn...")
                onProgress(job)
                try fileManager.removeItem(at: sourceURL)
                
                if createSymlink {
                    job.status = .creatingSymlink
                    job.statusDetail = L10n.tr("Đang tạo symlink...")
                    onProgress(job)
                    try fileManager.createSymbolicLink(
                        atPath: sourcePath,
                        withDestinationPath: destinationURL.path
                    )
                }
            }
            
            job.status = .completed
            job.statusDetail = L10n.tr("Hoàn thành!")
            job.currentFile = nil
            onProgress(job)
            
        } catch let error as ShuttleError {
            job.status = .failed
            job.errorMessage = error.localizedDescription
            onProgress(job)
            throw error
        } catch {
            job.status = .failed
            job.errorMessage = error.localizedDescription
            onProgress(job)
            throw ShuttleError.copyFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Job Management
    
    /// Cancel a running job
    func cancelJob(_ job: TransferJob) {
        job.isCancelled = true
        job.status = .cancelled
        job.statusDetail = L10n.tr("Đã hủy")
    }
    
    func clearCompletedJobs() {
        activeJobs.removeAll { $0.status == .completed || $0.status == .failed || $0.status == .cancelled }
    }
    
    /// Extract volume name from a path like /Volumes/MyDrive/some/path → MyDrive
    nonisolated private func extractVolumeName(from path: String) -> String {
        let components = path.split(separator: "/")
        if components.count >= 2 && components[0] == "Volumes" {
            return String(components[1])
        }
        return "Macintosh HD"
    }
}

// MARK: - Sync Profile Execution

struct SyncProfileExecutionResult: Sendable {
    let totalCount: Int
    let successCount: Int
    let failureCount: Int
    
    var summary: String {
        failureCount == 0 ? L10n.tr("Hoàn thành") : L10n.formatted("%lld OK, %lld lỗi", Int64(successCount), Int64(failureCount))
    }
}

extension FileShuttleService {
    /// Runs a sync profile and persists successful shuttle items into SwiftData.
    func executeProfile(
        _ profile: SyncProfile,
        modelContext: ModelContext,
        onProgress: @MainActor @Sendable @escaping (String?) -> Void = { _ in }
    ) async -> SyncProfileExecutionResult {
        var successCount = 0
        var failureCount = 0
        
        for (index, itemPath) in profile.items.enumerated() {
            let folderName = URL(fileURLWithPath: itemPath).lastPathComponent
            onProgress("[\(index + 1)/\(profile.items.count)] \(folderName)...")
            
            do {
                if profile.direction == "shuttle" {
                    let item = try await shuttle(
                        sourcePath: itemPath,
                        destinationBasePath: profile.destinationPath,
                        onProgress: { job in
                            onProgress("[\(index + 1)/\(profile.items.count)] \(folderName): \(job.progressPercentage)%")
                        }
                    )
                    modelContext.insert(item)
                    try modelContext.save()
                } else {
                    try await importToMain(
                        sourcePath: itemPath,
                        destinationPath: profile.destinationPath,
                        deleteSource: true,
                        onProgress: { job in
                            onProgress("[\(index + 1)/\(profile.items.count)] \(folderName): \(job.progressPercentage)%")
                        }
                    )
                }
                
                successCount += 1
            } catch {
                failureCount += 1
            }
        }
        
        profile.lastExecuted = Date()
        try? modelContext.save()
        onProgress(nil)
        
        return SyncProfileExecutionResult(
            totalCount: profile.items.count,
            successCount: successCount,
            failureCount: failureCount
        )
    }
}
