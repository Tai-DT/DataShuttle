import Foundation

extension Int64 {
    /// Format bytes to human-readable string
    var formattedBytes: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        formatter.includesActualByteCount = false
        return formatter.string(fromByteCount: self)
    }
    
    /// Format bytes with decimal precision
    var formattedBytesDetailed: String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var size = Double(self)
        var unitIndex = 0
        
        while size >= 1024 && unitIndex < units.count - 1 {
            size /= 1024
            unitIndex += 1
        }
        
        if unitIndex == 0 {
            return String(format: "%.0f %@", size, units[unitIndex])
        } else {
            return String(format: "%.1f %@", size, units[unitIndex])
        }
    }
}

extension Double {
    /// Format as percentage string
    var percentageString: String {
        return String(format: "%.1f%%", self * 100)
    }
}

extension Date {
    /// Relative time string
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
