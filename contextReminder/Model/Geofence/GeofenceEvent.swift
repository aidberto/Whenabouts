//
//  GeofenceEvent.swift
//  contextReminder
//
//  What the GeofenceCoordinator emits when a reminder should fire.
//  The trigger engine catches these and turns them into notifications.
//

import Foundation

struct GeofenceEvent: Equatable {
    /// The id of the reminder trigger that fired.
    let triggerId: UUID
    /// Whether this was an "arriving" or "leaving" event.
    let kind: TriggerType
    /// When the event happened.
    let timestamp: Date
}
