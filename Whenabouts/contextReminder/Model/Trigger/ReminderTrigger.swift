//
//  ReminderTrigger.swift
//  contextReminder
//
//  Created by Brian Jones Porianto on 2/5/2026.
//

import Foundation
//fire the reminder based on the condition
struct ReminderTrigger: Identifiable, Codable, Equatable {
    let id: UUID
    var triggerType: TriggerType
    var target: ReminderTarget

    init(
        id: UUID = UUID(),
        triggerType: TriggerType,
        target: ReminderTarget
    ) {
        self.id = id
        self.triggerType = triggerType
        self.target = target
    }
}
