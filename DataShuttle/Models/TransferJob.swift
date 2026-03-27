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
    case pending = "pending"
    case inProgress = "inProgress"
    case creatingSymlink = "creatingSymlink"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending: return L10n.tr("Đang chờ")
        case .inProgress: return L10n.tr("Đang chuyển")
        case .creatingSymlink: return L10n.tr("Tạo symlink")
        case .completed: return L10n.tr("Hoàn thành")
        case .failed: return L10n.tr("Thất bại")
        case .cancelled: return L10n.tr("Đã hủy")
        }
    }
    
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
