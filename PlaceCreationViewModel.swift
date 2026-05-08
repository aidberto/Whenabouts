//
//  RegionMonitoring.swift
//  contextReminder
//
// watch particular geofence and perform actions when a user enters/leaves a certain boundary

import Foundation

protocol RegionMonitoring: AnyObject {
    /// IDs of every circle we're currently watching.
    var monitoredRegionIds: Set<UUID> { get }

    // Closure that gets called when the user enters or leaves a watched circle.
    // GeofenceCoordinator sets this so it can react to events.
    var onRegionTransition: ((UUID, RegionTransition) -> Void)? { get set }

    // Start watching a circle on the map.
    func startMonitoring(id: UUID, coordinate: LocationCoordinate, radius: Double)

    // Stop watching the circle with this id.
    func stopMonitoring(id: UUID)
}
