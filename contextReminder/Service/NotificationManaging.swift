
import Foundation

protocol NotificationManaging {
    func requestPermission() async -> Bool
    func notificationPermissionStatus() async -> Bool
    func sendReminderNotification(
        title: String,
        body: String,
        identifier: String
    )
    func scheduleReminderNotification(
        title: String,
        body: String,
        identifier: String,
        at date: Date
    )
    func cancelNotification(identifier: String)
}
