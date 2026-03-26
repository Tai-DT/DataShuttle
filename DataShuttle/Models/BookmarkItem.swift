import Foundation
import SwiftData

/// A bookmarked folder for quick shuttle/import
@Model
final class BookmarkItem {
    /// Path of the bookmarked folder
    var path: String
    
    /// Display name
    var name: String
    
    /// Preferred destination path (where it usually goes)
    var preferredDestination: String?
    
    /// Preferred direction: "shuttle" (main→external) or "import" (external→main)
    var directionRaw: String
    
    /// Volume name where the folder lives
    var volumeName: String
    
    /// Last used date
    var lastUsed: Date?
    
    /// Times used
    var useCount: Int
    
    /// Created date
    var createdAt: Date
    
    /// Color tag (for visual grouping)
    var colorTag: String
    
    var direction: BookmarkDirection {
        get { BookmarkDirection(rawValue: directionRaw) ?? .shuttle }
        set { directionRaw = newValue.rawValue }
    }
    
    init(
        path: String,
        name: String,
        preferredDestination: String? = nil,
        direction: BookmarkDirection = .shuttle,
        volumeName: String = "",
        colorTag: String = "blue"
    ) {
        self.path = path
        self.name = name
        self.preferredDestination = preferredDestination
        self.directionRaw = direction.rawValue
        self.volumeName = volumeName
        self.lastUsed = nil
        self.useCount = 0
        self.createdAt = Date()
        self.colorTag = colorTag
    }
}

enum BookmarkDirection: String, CaseIterable {
    case shuttle = "shuttle"     // main → external
    case importToMain = "import" // external → main
    
    var displayName: String {
        switch self {
        case .shuttle: return "Chính → Phụ"
        case .importToMain: return "Phụ → Chính"
        }
    }
    
    var icon: String {
        switch self {
        case .shuttle: return "arrow.right.circle.fill"
        case .importToMain: return "arrow.left.circle.fill"
        }
    }
}
