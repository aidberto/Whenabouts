//
//  NotificationService.swift
//  contextReminder
//
//  Wraps UNUserNotificationCenter. Responsible for requesting permission and
//  firing a local notification when a geofence event matches a reminder.
//
//  Keeps a per-reminder cooldown so we don't spam the user every time they
//  briefly cross a boundary. Default cooldown is 1 hour.
//

import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()

    /// How long (seconds) to wait before re-notifying for the same reminder.
    private let cooldownInterval: TimeInterval = 60 * 60  // 1 hour

    /// reminderId → last notification date
    private var lastFired: [UUID: Date] = [:]

    private init() {}

    // MARK: - Permission

    /// Request notification permission. Safe to call multiple times — iOS
    /// only shows the prompt once.
    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            print("NotificationService: permission granted = \(granted)")
        } catch {
            print("NotificationService: authorization error = \(error)")
        }
    }

    // MARK: - Firing

    /// Schedule an immediate notification for a reminder that just triggered.
    /// Silently skipped if the same reminder fired within the cooldown window.
    func fire(reminder: Reminder, triggerDescription: String) {
        // Cooldown check
        if let last = lastFired[reminder.id],
           Date().timeIntervalSince(last) < cooldownInterval {
            print("NotificationService: skipping \(reminder.title) — still in cooldown")
            return
        }
        lastFired[reminder.id] = Date()

        let content = UNMutableNotificationContent()
        content.title = notificationTitle(for: reminder)
        content.body = notificationBody(for: reminder, triggerDescription: triggerDescription)
        content.sound = notificationSound(for: reminder.priority)
        content.badge = 1
        content.userInfo = ["reminderId": reminder.id.uuidString]

        // Fire after 1 second (can't fire at t=0 with UNTimeIntervalNotificationTrigger)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "reminder-\(reminder.id.uuidString)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("NotificationService: failed to schedule — \(error)")
            } else {
                print("NotificationService: fired '\(reminder.title)'")
            }
        }
    }

    // MARK: - Helpers

    private func notificationTitle(for reminder: Reminder) -> String {
        switch reminder.priority {
        case .urgent: return "🔴 \(reminder.title)"
        case .high:   return "🟠 \(reminder.title)"
        case .normal: return "🔵 \(reminder.title)"
        case .low:    return "⚪️ \(reminder.title)"
        }
    }

    private func notificationBody(for reminder: Reminder, triggerDescription: String) -> String {
        var parts: [String] = [triggerDescription]
        if !reminder.notes.isEmpty {
            parts.append(reminder.notes)
        }
        if !reminder.checklist.isEmpty {
            let pending = reminder.checklist.filter { !$0.isCompleted }
            if !pending.isEmpty {
                parts.append("\(pending.count) checklist item(s) remaining")
            }
        }
        return parts.joined(separator: " • ")
    }

    private func notificationSound(for priority: ReminderPriority) -> UNNotificationSound {
        switch priority {
        case .urgent: return .defaultCritical
        default:      return .default
        }
    }
}
