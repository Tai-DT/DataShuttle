import Foundation
import UserNotifications

/// Manages macOS user notifications
final class NotificationManager {
    static let shared = NotificationManager()
    
    private var isAuthorized = false
    private var didConfigureAuthorization = false
    
    private init() {}
    
    func configureAuthorizationIfNeeded() {
        guard !didConfigureAuthorization else { return }
        didConfigureAuthorization = true
        refreshAuthorizationStatus(promptIfNeeded: true)
    }
    
    func requestPermission() {
        refreshAuthorizationStatus(promptIfNeeded: true)
    }
    
    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
            }
            
            if let error {
                self?.handleAuthorizationError(error)
            }
        }
    }
    
    /// Check current authorization status and update local flag
    func refreshAuthorizationStatus() {
        refreshAuthorizationStatus(promptIfNeeded: false)
    }
    
    private func refreshAuthorizationStatus(promptIfNeeded: Bool) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let isAllowed: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                isAllowed = true
            default:
                isAllowed = false
            }
            
            DispatchQueue.main.async {
                self?.isAuthorized = isAllowed
            }
            
            if promptIfNeeded && settings.authorizationStatus == .notDetermined {
                self?.requestAuthorization()
            }
        }
    }
    
    func send(title: String, body: String, identifier: String) {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // Fire immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                if self.isNotificationsNotAllowedError(error) {
                    self.refreshAuthorizationStatus()
                    return
                }
                
                print("⚠️ Failed to deliver notification: \(error.localizedDescription)")
            }
        }
    }
    
    func sendTransferComplete(folderName: String, direction: String) {
        send(
            title: "✅ Chuyển thành công",
            body: "\"\(folderName)\" đã được \(direction) hoàn tất.",
            identifier: "transfer-complete-\(UUID().uuidString)"
        )
    }
    
    func sendTransferFailed(folderName: String, error: String) {
        send(
            title: "❌ Chuyển thất bại",
            body: "\"\(folderName)\": \(error)",
            identifier: "transfer-failed-\(UUID().uuidString)"
        )
    }
    
    private func handleAuthorizationError(_ error: Error) {
        if isNotificationsNotAllowedError(error) {
            return
        }
        
        print("⚠️ Notification permission error: \(error.localizedDescription)")
    }
    
    private func isNotificationsNotAllowedError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == UNErrorDomain
            && nsError.code == UNError.Code.notificationsNotAllowed.rawValue
    }
}
