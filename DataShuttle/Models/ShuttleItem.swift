import Foundation
import SwiftData

/// Represents a directory that has been "shuttled" from primary to secondary drive
@Model
final class ShuttleItem {
    /// Original path on the primary drive
    var originalPath: String
    
    /// Destination path on the secondary drive
    var destinationPath: String
    
    /// Display name of the folder
    var folderName: String
    
    /// Size in bytes when shuttled
    var sizeBytes: Int64
    
    /// When the shuttle operation was performed
    var shuttledAt: Date
    
    /// Current status
    var statusRaw: String
    
    /// Volume name of the destination
    var destinationVolume: String
    
    var status: ShuttleStatus {
        get { ShuttleStatus(rawValue: statusRaw) ?? .shuttled }
        set { statusRaw = newValue.rawValue }
    }
    
    init(originalPath: String, destinationPath: String, folderName: String, sizeBytes: Int64, destinationVolume: String) {
        self.originalPath = originalPath
        self.destinationPath = destinationPath
        self.folderName = folderName
        self.sizeBytes = sizeBytes
        self.shuttledAt = Date()
        self.statusRaw = ShuttleStatus.shuttled.rawValue
        self.destinationVolume = destinationVolume
    }
}

enum ShuttleStatus: String, CaseIterable {
    case shuttled = "shuttled"
    case restored = "restored"
    case transferring = "transferring"
    case error = "error"
    
    var displayName: String {
        switch self {
        case .shuttled: return L10n.tr("Đã chuyển")
        case .restored: return L10n.tr("Đã khôi phục")
        case .transferring: return L10n.tr("Đang chuyển")
        case .error: return L10n.tr("Lỗi")
        }
    }
    
    var iconName: String {
        switch self {
        case .shuttled: return "checkmark.circle.fill"
        case .restored: return "arrow.uturn.backward.circle.fill"
        case .transferring: return "arrow.triangle.2.circlepath"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .shuttled: return "green"
        case .restored: return "blue"
        case .transferring: return "orange"
        case .error: return "red"
        }
    }
}
