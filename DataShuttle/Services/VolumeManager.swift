import Foundation

/// Service to detect and manage mounted volumes
@Observable
class VolumeManager {
    var volumes: [VolumeInfo] = []
    var mainVolume: VolumeInfo?
    var secondaryVolumes: [VolumeInfo] = []
    
    private let fileManager = FileManager.default
    
    init() {
        Task { @MainActor in
            refreshVolumes()
        }
    }
    
    @MainActor
    func refreshVolumes() {
        volumes = []
        
        // Get all mounted volumes
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeIsRemovableKey,
            .volumeIsInternalKey,
            .volumeLocalizedNameKey
        ]
        
        guard let mountedVolumeURLs = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) else { return }
        
        for volumeURL in mountedVolumeURLs {
            do {
                let resourceValues = try volumeURL.resourceValues(forKeys: Set(keys))
                
                let name = resourceValues.volumeLocalizedName ?? resourceValues.volumeName ?? "Unknown"
                let totalBytes = Int64(resourceValues.volumeTotalCapacity ?? 0)
                let availableBytes = Int64(resourceValues.volumeAvailableCapacity ?? 0)
                let isRemovable = resourceValues.volumeIsRemovable ?? false
                let isInternal = resourceValues.volumeIsInternal ?? true
                
                // Skip tiny or system volumes
                guard totalBytes > 1_000_000_000 else { continue } // Skip < 1GB
                
                let volume = VolumeInfo(
                    id: volumeURL.path,
                    name: name,
                    mountPoint: volumeURL.path,
                    totalBytes: totalBytes,
                    availableBytes: availableBytes,
                    isRemovable: isRemovable,
                    isInternal: isInternal
                )
                
                volumes.append(volume)
            } catch {
                print("Error reading volume info for \(volumeURL): \(error)")
            }
        }
        
        // Classify volumes
        mainVolume = volumes.first(where: { $0.isMainDrive })
        secondaryVolumes = volumes.filter { !$0.isMainDrive }
    }
    
    func getVolume(for path: String) -> VolumeInfo? {
        // Find the volume that contains this path
        return volumes
            .filter { path.hasPrefix($0.mountPoint) }
            .sorted { $0.mountPoint.count > $1.mountPoint.count }
            .first
    }
}
