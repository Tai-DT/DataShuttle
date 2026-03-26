import Foundation

/// Represents an ongoing transfer operation.
/// Properties are accessed from both main actor (UI) and background threads (file copy).
/// Using @unchecked Sendable since we accept controlled cross-thread mutation during file transfer.
@Observable
class TransferJob: Identifiable, @unchecked Sendable {
    let id = UUID()
    let sourcePath: String
    let destinationPath: String
    let folderName: String
    let totalBytes: Int64
    var transferredBytes: Int64 = 0
    var status: TransferStatus = .pending
    var errorMessage: String?
    let isRestore: Bool
    
    /// Flag to cancel the transfer
    var isCancelled = false
    
    /// Current file being transferred
    var currentFile: String?
    
    /// Human-readable status detail
    var statusDetail: String?
    
    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return min(Double(transferredBytes) / Double(totalBytes), 1.0)
    }
    
    var progressPercentage: Int {
        Int(progress * 100)
    }
    
    init(sourcePath: String, destinationPath: String, folderName: String, totalBytes: Int64, isRestore: Bool = false) {
        self.sourcePath = sourcePath
        self.destinationPath = destinationPath
        self.folderName = folderName
        self.totalBytes = totalBytes
        self.isRestore = isRestore
    }
}

enum TransferStatus: String, Sendable {
    case pending = "Đang chờ"
    case inProgress = "Đang chuyển"
    case creatingSymlink = "Tạo symlink"
    case completed = "Hoàn thành"
    case failed = "Thất bại"
    case cancelled = "Đã hủy"
    
    var iconName: String {
        switch self {
        case .pending: return "clock.fill"
        case .inProgress: return "arrow.right.circle.fill"
        case .creatingSymlink: return "link.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "minus.circle.fill"
        }
    }
}
