//
//  FakeNotificationService.swift
//  contextReminder
//
//  Test double for NotificationService. Records which reminders were notified
//  so unit tests can assert on them without actually scheduling system notifications.
//

import Foundation

#if DEBUG
final class FakeNotificationService {
    private(set) var firedReminders: [(reminder: Reminder, description: String)] = []

    func fire(reminder: Reminder, triggerDescription: String) {
        firedReminders.append((reminder, triggerDescription))
        print("FakeNotificationService: would fire '\(reminder.title)' — \(triggerDescription)")
    }

    func reset() {
        firedReminders.removeAll()
    }
}
#endif

