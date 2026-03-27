import Foundation
import AppKit

/// Monitors drive mount/unmount events in realtime
@Observable
class DriveMonitor {
    
    struct DriveEvent: Identifiable {
        let id = UUID()
        let volumeName: String
        let mountPoint: String
        let eventType: EventType
        let timestamp: Date
        
        enum EventType: String {
            case mounted
            case unmounted
            
            var displayName: String {
                switch self {
                case .mounted: return L10n.tr("Đã kết nối")
                case .unmounted: return L10n.tr("Đã ngắt")
                }
            }
        }
    }
    
    var recentEvents: [DriveEvent] = []
    var isMonitoring = false
    
    /// Callback when drive mounts (for scheduled shuttle)
    var onDriveMount: ((String, String) -> Void)?
    /// Callback when drive unmounts (for health warning)
    var onDriveUnmount: ((String) -> Void)?
    
    private var mountObserver: NSObjectProtocol?
    private var unmountObserver: NSObjectProtocol?
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        let workspace = NSWorkspace.shared.notificationCenter
        
        mountObserver = workspace.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let volumeURL = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
            let name = volumeURL.lastPathComponent
            let mountPoint = volumeURL.path
            
            let event = DriveEvent(
                volumeName: name,
                mountPoint: mountPoint,
                eventType: .mounted,
                timestamp: Date()
            )
            self?.recentEvents.insert(event, at: 0)
            if (self?.recentEvents.count ?? 0) > 20 {
                self?.recentEvents.removeLast()
            }
            
            self?.onDriveMount?(name, mountPoint)
            
            NotificationManager.shared.send(
                title: L10n.tr("Ổ đĩa đã kết nối"),
                body: L10n.formatted("Ổ \"%@\" đã được cắm vào máy.", name),
                identifier: "drive-mount-\(name)"
            )
        }
        
        unmountObserver = workspace.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let volumeURL = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
            let name = volumeURL.lastPathComponent
            
            let event = DriveEvent(
                volumeName: name,
                mountPoint: volumeURL.path,
                eventType: .unmounted,
                timestamp: Date()
            )
            self?.recentEvents.insert(event, at: 0)
            
            self?.onDriveUnmount?(name)
            
            NotificationManager.shared.send(
                title: L10n.tr("⚠️ Ổ đĩa đã ngắt"),
                body: L10n.formatted("Ổ \"%@\" đã bị ngắt kết nối. Một số symlink có thể bị ảnh hưởng.", name),
                identifier: "drive-unmount-\(name)"
            )
        }
    }
    
    func stopMonitoring() {
        if let observer = mountObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = unmountObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        isMonitoring = false
    }
    
    deinit {
        stopMonitoring()
    }
}
