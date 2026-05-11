//
//  RemindersViewModel.swift
//  contextReminder
//
//  Created by Aiden Bertovic on 5/5/2026.
//
//  Provides saved reminders and places to the reminders screen, and handles
//  creating, editing, deleting, and marking reminders as complete.

import Foundation
import Combine

@MainActor
final class RemindersViewModel: ObservableObject {
    private let reminderStore: any ReminderStore
    private let placeStore: any PlaceStore
    private let notificationManager: any NotificationManaging
    private var cancellables = Set<AnyCancellable>()
    
    var onRemindersChanged: (() -> Void)?

    var reminders: [Reminder] {
        reminderStore.reminders.sorted { first, second in
            if first.isCompleted != second.isCompleted {
                return !first.isCompleted
            }
            return first.createdAt > second.createdAt
        }
    }

    var places: [Place] {
        placeStore.places
    }

    init(
        reminderStore: any ReminderStore,
        placeStore: any PlaceStore,
        notificationManager: any NotificationManaging
    ) {
        self.reminderStore = reminderStore
        self.placeStore = placeStore
        self.notificationManager = notificationManager

        reminderStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        placeStore.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func delete(at offsets: IndexSet) {
        let currentReminders = reminders
        for index in offsets {
            let reminder = currentReminders[index]
            notificationManager.cancelNotification(identifier: timeNotificationIdentifier(for: reminder))
            reminderStore.delete(id: reminder.id)
        }
        
        onRemindersChanged?()
    }

    func toggleCompleted(_ reminder: Reminder) {
        var updated = reminder
        updated.isCompleted.toggle()
        if updated.isCompleted {
            notificationManager.cancelNotification(identifier: timeNotificationIdentifier(for: updated))
        } else {
            scheduleTimeNotificationIfNeeded(for: updated)
        }
        reminderStore.update(updated)
        onRemindersChanged?()
    }

    func save(_ reminder: Reminder) {
        if reminder.isCompleted {
            notificationManager.cancelNotification(identifier: timeNotificationIdentifier(for: reminder))
        } else {
            scheduleTimeNotificationIfNeeded(for: reminder)
        }

        if reminderStore.reminders.contains(where: { $0.id == reminder.id }) {
            reminderStore.update(reminder)
        } else {
            reminderStore.add(reminder)
        }
        
        onRemindersChanged?()
    }

    private func scheduleTimeNotificationIfNeeded(for reminder: Reminder) {
        let identifier = timeNotificationIdentifier(for: reminder)
        guard let scheduledAt = reminder.scheduledAt else {
            notificationManager.cancelNotification(identifier: identifier)
            return
        }

        notificationManager.scheduleReminderNotification(
            title: reminder.title,
            body: reminder.notes.isEmpty ? "You have a reminder." : reminder.notes,
            identifier: identifier,
            at: scheduledAt
        )
    }

    private func timeNotificationIdentifier(for reminder: Reminder) -> String {
        "\(reminder.id.uuidString)-time"
    }
}
