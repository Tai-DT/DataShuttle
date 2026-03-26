import Foundation
import UserNotifications

/// Manages macOS user notifications
class NotificationManager {
    static let shared = NotificationManager()
    
    private var isAuthorized = false
    
    private init() {}
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
            }
            if let error = error {
                print("⚠️ Notification permission error: \(error.localizedDescription)")
            }
            if granted {
                print("✅ Notifications authorized")
            } else {
                print("⚠️ Notifications denied — app will work without notifications")
            }
        }
    }
    
    /// Check current authorization status and update local flag
    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.isAuthorized = settings.authorizationStatus == .authorized
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
            if let error = error {
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
}

