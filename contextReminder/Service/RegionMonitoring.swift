//
//  RegionMonitoring.swift
//  contextReminder
//
//  Describes "the thing that watches geofence circles."
//
//  A geofence is just a circle on a map. iOS can watch up to 20 of them at once
//  and tell us when the user crosses one. This protocol is the small interface
//  the rest of the app uses — start watching a circle, stop watching one, and
//  let me know when something happens.
//
//  In the real app, CoreLocationProvider does this work.
//  In tests, FakeRegionMonitor does it without any real GPS.
//

import Foundation

protocol RegionMonitoring: AnyObject {
    /// IDs of every circle we're currently watching.
    var monitoredRegionIds: Set<UUID> { get }

    /// Closure that gets called when the user enters or leaves a watched circle.
    /// `GeofenceCoordinator` sets this so it can react to events.
    var onRegionTransition: ((UUID, RegionTransition) -> Void)? { get set }

    /// Start watching a circle on the map.
    func startMonitoring(id: UUID, coordinate: LocationCoordinate, radius: Double)

    /// Stop watching the circle with this id.
    func stopMonitoring(id: UUID)
}
