//
//  Reminder.swift
//  contextReminder
//
//  Created by Ameen A on 5/5/2026.
//

import Foundation

struct Reminder: Identifiable, Codable, Equatable {
    let id: UUID

    var title: String
    var notes: String?
    var category: ReminderCategory
    var checklist: [ChecklistItem]
    var priority: ReminderPriority

    var triggerType: TriggerType
    var placeType: PlaceType?

    var isCompleted: Bool
    var completedAt: Date?
    var dismissedUntil: Date?
    var missedCount: Int

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        category: ReminderCategory = .general,
        checklist: [ChecklistItem] = [],
        priority: ReminderPriority = .normal,
        triggerType: TriggerType,
        placeType: PlaceType? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        dismissedUntil: Date? = nil,
        missedCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.category = category
        self.checklist = checklist
        self.priority = priority
        self.triggerType = triggerType
        self.placeType = placeType
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.dismissedUntil = dismissedUntil
        self.missedCount = missedCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

