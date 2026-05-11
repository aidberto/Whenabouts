
import Foundation

struct Reminder: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var notes: String
    var category: ReminderCategory
    var priority: ReminderPriority
    var trigger: ReminderTrigger
    var scheduledAt: Date?
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
        scheduledAt: Date? = nil,
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
        self.scheduledAt = scheduledAt
        self.checklist = checklist
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

extension Reminder {
    var notificationTitle: String {
        "Whenabouts \(category.emoji)"
    }

    var notificationBody: String {
        title
    }
}
