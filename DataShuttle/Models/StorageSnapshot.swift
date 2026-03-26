import Foundation
import SwiftData

/// Records storage snapshots for analytics over time
@Model
class StorageSnapshot {
    var date: Date
    var volumeName: String
    var totalBytes: Int64
    var usedBytes: Int64
    var availableBytes: Int64
    var shuttledBytes: Int64 // How much DataShuttle saved
    
    init(volumeName: String, totalBytes: Int64, usedBytes: Int64, availableBytes: Int64, shuttledBytes: Int64 = 0) {
        self.date = Date()
        self.volumeName = volumeName
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.availableBytes = availableBytes
        self.shuttledBytes = shuttledBytes
    }
    
    var usagePercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes)
    }
}
