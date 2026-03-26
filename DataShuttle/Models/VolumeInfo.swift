import Foundation

/// Represents a mounted volume/drive
struct VolumeInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let mountPoint: String
    let totalBytes: Int64
    let availableBytes: Int64
    let isRemovable: Bool
    let isInternal: Bool
    
    var usedBytes: Int64 {
        totalBytes - availableBytes
    }
    
    var usagePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
    
    var isMainDrive: Bool {
        mountPoint == "/" || mountPoint == "/System/Volumes/Data"
    }
    
    var volumeIcon: String {
        if isMainDrive {
            return "internaldrive.fill"
        } else if isRemovable {
            return "externaldrive.fill"
        } else {
            return "externaldrive.fill.badge.plus"
        }
    }
    
    var displayType: String {
        if isMainDrive {
            return "Ổ đĩa chính"
        } else if isRemovable {
            return "Ổ đĩa ngoài"
        } else {
            return "Ổ đĩa phụ"
        }
    }
}
