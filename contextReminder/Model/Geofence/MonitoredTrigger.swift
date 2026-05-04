//
//  MonitoredTrigger.swift
//  contextReminder
//
//  One geofence circle the GeofenceCoordinator should watch.
//  Built fresh by whoever feeds the coordinator (the trigger engine).
//  Carries everything the coordinator needs: id, where, how big, what kind,
//  and when it last fired (so we can avoid spamming the user).
//

import Foundation

struct MonitoredTrigger: Identifiable, Equatable {
    let id: UUID
    let coordinate: LocationCoordinate
    let radius: Double
    let triggerType: TriggerType
    /// When this trigger most recently fired. Nil if it's never fired.
    /// Used to skip firing again too soon (60-second debounce).
    let lastTriggeredAt: Date?
}
