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
    private var cancellables = Set<AnyCancellable>()

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

    init(reminderStore: any ReminderStore, placeStore: any PlaceStore) {
        self.reminderStore = reminderStore
        self.placeStore = placeStore

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
            reminderStore.delete(id: currentReminders[index].id)
        }
    }

    func toggleCompleted(_ reminder: Reminder) {
        var updated = reminder
        updated.isCompleted.toggle()
        reminderStore.update(updated)
    }

    func save(_ reminder: Reminder) {
        if reminderStore.reminders.contains(where: { $0.id == reminder.id }) {
            reminderStore.update(reminder)
        } else {
            reminderStore.add(reminder)
        }
    }
}
