//
//  ReminderTriggerCoordinator.swift
//  contextReminder
//
//  Created by Ameen A on 8/5/2026.
//

import Foundation

final class ReminderTriggerCoordinator {
    
    private let reminderStore: JSONReminderStore
    private let notificationManager: NotificationManaging
    
    init(
        reminderStore: JSONReminderStore,
        notificationManager: NotificationManaging = LocalNotificationManager.shared
    ) {
        self.reminderStore = reminderStore
        self.notificationManager = notificationManager
    }
    
    func handleGeofenceEvent(
        place: Place,
        transition: RegionTransition
    ){
        let matchingReminders = reminderStore.reminders.filter { reminder in
            guard !reminder.isCompleted else {
                return false
            }
            
            guard matchesTransition(
                reminder.trigger.triggerType,
                transition
            ) else {
                return false
            }
            
            return matchesTarget(
                reminder.trigger.target,
                place
            )
        }
        
        for reminder in matchingReminders {
            notificationManager.sendReminderNotification(
                title: reminder.title,
                body: reminder.notes.isEmpty ? "You have a reminder."
                : reminder.notes,
                identifier: reminder.id.uuidString
            )
        }
    }
    
    private func matchesTransition(
        _ triggerType: TriggerType,
        _ transition: RegionTransition
    ) -> Bool {
        
        switch (triggerType, transition){
            
        case (.arriving, .enter):
            return true
            
        case (.leaving, .exit):
            return true
            
        default:
            return false
        }
    }
    
    private func matchesTarget(
        _ target: ReminderTarget,
        _ place: Place
    ) -> Bool {
        
        switch target {
        case .place(let targetPlace):
            return targetPlace.id == place.id
            
        case .placeType(let placeType):
            return place.placeType == placeType
        }
    }
}
