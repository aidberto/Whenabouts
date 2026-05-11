
import Foundation

final class ReminderTriggerCoordinator {
    
    private let reminderStore: JSONReminderStore
    private let notificationManager: NotificationManaging
    
    init(
        reminderStore: JSONReminderStore,
        notificationManager: NotificationManaging = LocalNotificationManager.shared
    ) {
        self.reminderStore = reminderStore
        self.notificationManager = notificationManager
    }
    
    func handleEvent(_ event: GeofenceEvent){
        print("Handling geofence for trigger: \(event.triggerId)")
        
        let matchingReminders = reminderStore.reminders.filter { reminder in
            
            guard !reminder.isCompleted else {
                return false
            }
            return reminder.trigger.id == event.triggerId
        }
        
        for reminder in matchingReminders {
            
            Task {
                
                let isAuthorized =
                await notificationManager.notificationPermissionStatus()
                
                guard isAuthorized else {
                    print("Notification not Authorized")
                    return
                }
                
                notificationManager.sendReminderNotification(
                    title: reminder.notificationTitle,
                    body: reminder.notificationBody,
                    identifier: reminder.id.uuidString
                )
            }
        }
    }
}
