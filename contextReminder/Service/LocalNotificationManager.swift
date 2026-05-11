
import Foundation
import UserNotifications

final class LocalNotificationManager: NSObject, NotificationManaging, UNUserNotificationCenterDelegate {
    
    static let shared = LocalNotificationManager()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification Permission Error: \(error)")
            return false
        }
    }
    
    func notificationPermissionStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        return settings.authorizationStatus == .authorized
    }
    
    func sendReminderNotification(title: String, body: String, identifier: String) {
        
        print("Sending notification \(title)")
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Notification Scheduling Failed: \(error)")
            }
        }
    }

    func scheduleReminderNotification(title: String, body: String, identifier: String, at date: Date) {
        cancelNotification(identifier: identifier)

        guard date > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("Timed Notification Scheduling Failed: \(error)")
            }
        }
    }

    func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
