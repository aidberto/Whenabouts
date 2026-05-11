//
//  Reminder.swift
//  contextReminder
//
//  Created by Aiden Bertovic on 5/5/2026.
//
//  Stores the data for one context reminder, including its location trigger,
//  priority, category, checklist items, and completion state.

import Foundation

struct Reminder: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var notes: String
    var category: ReminderCategory
    var priority: ReminderPriority
    var trigger: ReminderTrigger
    var checklist: [ChecklistItem]
    var isCompleted: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        category: ReminderCategory = .general,
        priority: ReminderPriority = .normal,
        trigger: ReminderTrigger,
        checklist: [ChecklistItem] = [],
        isCompleted: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.category = category
        self.priority = priority
        self.trigger = trigger
        self.checklist = checklist
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}
