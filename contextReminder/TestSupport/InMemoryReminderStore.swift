//
//  InMemoryReminderStore.swift
//  contextReminder
//
//  Created by Voreak Sanith on 8/5/2026.
//

import Foundation
import Combine

final class InMemoryReminderStore: ReminderStore {
    @Published private(set) var reminders: [Reminder] = []
    
    init(reminders: [Reminder] = []) {
        self.reminders = reminders
    }
    
    func add(_ reminder: Reminder){
        reminders.append(reminder)
    }
    
    func update(_ reminder: Reminder){
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id})else {return}
        reminders[index] = reminder
    }
    
    func delete(id: UUID){
        reminders.removeAll { $0.id == id}
    }
    
}
