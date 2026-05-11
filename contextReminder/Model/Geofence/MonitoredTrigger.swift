//
//  MonitoredTrigger.swift
//  contextReminder
//
//  One geofence circle the GeofenceCoordinator should watch.
//  Built fresh by whoever feeds the coordinator (the trigger engine).
//  Carries everything the coordinator needs: region id, reminder trigger id,
//  where, how big, what kind, and when it last fired.
//

import Foundation

struct MonitoredTrigger: Identifiable, Equatable {
    let regionId: UUID
    let reminderTriggerId: UUID
    let coordinate: LocationCoordinate
    let radius: Double
    let triggerType: TriggerType
    /// When this trigger most recently fired. Nil if it's never fired.
    /// Used to skip firing again too soon (60-second debounce).
    let lastTriggeredAt: Date?

    var id: UUID { regionId }

    init(
        id: UUID,
        reminderTriggerId: UUID? = nil,
        coordinate: LocationCoordinate,
        radius: Double,
        triggerType: TriggerType,
        lastTriggeredAt: Date?
    ) {
        self.regionId = id
        self.reminderTriggerId = reminderTriggerId ?? id
        self.coordinate = coordinate
        self.radius = radius
        self.triggerType = triggerType
        self.lastTriggeredAt = lastTriggeredAt
    }
}
