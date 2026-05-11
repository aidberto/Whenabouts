//
//  JSONReminderStore.swift
//  contextReminder
//
//  Created by Aiden Bertovic on 5/5/2026.
//
//  Defines the reminder store interface and saves reminders to a JSON file in
//  the apps Application Support folder.

import Foundation
import Combine

protocol ReminderStore: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    var reminders: [Reminder] { get }

    func add(_ reminder: Reminder)
    func update(_ reminder: Reminder)
    func delete(id: UUID)
}

final class JSONReminderStore: ReminderStore {
    @Published private(set) var reminders: [Reminder] = []

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        load()
    }

    func add(_ reminder: Reminder) {
        reminders.append(reminder)
        save()
    }

    func update(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else {
            return
        }
        reminders[index] = reminder
        save()
    }

    func delete(id: UUID) {
        reminders.removeAll { $0.id == id }
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            reminders = try JSONDecoder().decode([Reminder].self, from: data)
        } catch {
            print("ReminderStore load failed: \(error)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(reminders)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("ReminderStore save failed: \(error)")
        }
    }

    private static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("reminders.json")
    }
}
