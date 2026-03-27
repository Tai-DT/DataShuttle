import Foundation
import SwiftData

/// A group of directories to shuttle/import together
@Model
class SyncProfile {
    var name: String
    var items: [String] // Array of source paths
    var destinationPath: String
    var direction: String // "shuttle" or "import"
    var triggerVolumeName: String? // Auto-trigger when this volume mounts
    var isEnabled: Bool
    var lastExecuted: Date?
    var colorTag: String
    var createdAt: Date
    
    init(
        name: String,
        items: [String],
        destinationPath: String,
        direction: String = "shuttle",
        triggerVolumeName: String? = nil,
        isEnabled: Bool = true,
        colorTag: String = "blue"
    ) {
        self.name = name
        self.items = items
        self.destinationPath = destinationPath
        self.direction = direction
        self.triggerVolumeName = triggerVolumeName
        self.isEnabled = isEnabled
        self.colorTag = colorTag
        self.createdAt = Date()
    }
    
    var itemCount: Int { items.count }
    
    var directionLabel: String {
        direction == "shuttle" ? L10n.tr("Chính → Phụ") : L10n.tr("Phụ → Chính")
    }
}
