import Foundation
import SwiftData

/// ViewModel for the main dashboard
@MainActor
@Observable
class DashboardViewModel {
    var volumeManager = VolumeManager()
    var isLoading = false
    var selectedVolume: VolumeInfo?
    
    var totalShuttledSize: Int64 = 0
    var shuttledItemCount: Int = 0
    
    func refresh() {
        isLoading = true
        volumeManager.refreshVolumes()
        isLoading = false
    }
    
    func updateStats(items: [ShuttleItem]) {
        let activeItems = items.filter { $0.status == .shuttled }
        shuttledItemCount = activeItems.count
        totalShuttledSize = activeItems.reduce(0) { $0 + $1.sizeBytes }
    }
}
