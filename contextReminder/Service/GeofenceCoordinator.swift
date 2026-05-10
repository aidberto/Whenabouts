//
//  GeofenceCoordinator.swift
//  contextReminder
//
//  The thing that decides which geofence circles iOS should watch right now.
//
//  Why this exists:
//    iOS lets us watch up to 20 circles at a time. If the user has reminders
//    for "any supermarket", "any pharmacy", "home", "work", we might want to
//    watch a lot more than 20 circles. This class picks the best 20.
//
//  What it does, step by step, every time the active list changes:
//    1. If there are more than 20 circles, keep the closest 20 to the user.
//    2. Compare to what's currently being watched. Only stop/start what changed.
//    3. If the user is already inside a newly-added "arriving" circle,
//       fire the reminder right now (otherwise iOS won't — it only fires
//       when the user crosses a boundary).
//    4. When iOS later reports a real cross, decide if it matches what the
//       user wanted (arriving vs leaving) and fire the event.
//

import Foundation

final class GeofenceCoordinator {
    /// Called whenever a reminder should fire. Set by whoever wants to listen
    /// (in production, by the trigger engine that turns events into notifications).
    var onEvent: ((GeofenceEvent) -> Void)?

    private let monitor: any RegionMonitoring
    private let regionCap: Int
    private let debounceWindow: TimeInterval

    /// Lookup table: region id → trigger info. Used when an event fires so
    /// we know which trigger it belongs to.
    private var activeTriggers: [UUID: MonitoredTrigger] = [:]

    init(
        monitor: any RegionMonitoring,
        regionCap: Int = 20,
        debounceWindow: TimeInterval = 60
    ) {
        self.monitor = monitor
        self.regionCap = regionCap
        self.debounceWindow = debounceWindow

        // Wire the monitor's "something happened" callback to our handler.
        // [weak self] avoids a memory leak if the coordinator is destroyed.
        monitor.onRegionTransition = { [weak self] id, transition in
            self?.handleTransition(id: id, transition: transition)
        }
    }

    /// Replace the active set of geofences. Call this whenever the set of
    /// reminders changes or the user moves significantly.
    func setActiveTriggers(
        _ triggers: [MonitoredTrigger],
        userLocation: LocationCoordinate?
    ) {
        // Step 1: cap to 20 (or whatever regionCap is).
        let selected = capSelect(triggers, userLocation: userLocation)

        // Step 2: figure out what changed since last call.
        let nextIds = Set(selected.map(\.id))
        let currentIds = monitor.monitoredRegionIds
        let toStop = currentIds.subtracting(nextIds)
        let toStart = nextIds.subtracting(currentIds)

        // Tell the monitor about the changes. Anything in both lists stays alone.
        for id in toStop {
            monitor.stopMonitoring(id: id)
        }
        for trigger in selected where toStart.contains(trigger.id) {
            monitor.startMonitoring(
                id: trigger.id,
                coordinate: trigger.coordinate,
                radius: trigger.radius
            )
        }

        // Update our lookup table.
        activeTriggers = Dictionary(uniqueKeysWithValues: selected.map { ($0.id, $0) })

        // Step 3: cold-start check. If the user is already inside a new arriving
        // circle, fire the event right now (iOS won't — it only fires on crosses).
        // We don't do this for leaving triggers — "user is inside" doesn't mean
        // "they just left", so firing now would be wrong.
        
        guard let userLocation else {
            print("No user location available")
            return }
        
        print(userLocation.latitude)
        print(userLocation.longitude)
        for trigger in selected where toStart.contains(trigger.id) {
            guard trigger.triggerType == .arriving else { continue }
            if isInside(userLocation, trigger: trigger), !isDebounced(trigger) {
                emit(triggerId: trigger.id, kind: .arriving)
            }
        }
    }

    /// Pick which triggers to actually watch when there are too many.
    /// Closest to the user first; if we don't know where the user is, just
    /// take the first N.
    private func capSelect(
        _ triggers: [MonitoredTrigger],
        userLocation: LocationCoordinate?
    ) -> [MonitoredTrigger] {
        guard triggers.count > regionCap else { return triggers }
        guard let userLocation else {
            return Array(triggers.prefix(regionCap))
        }
        return triggers
            .sorted {
                distance(from: userLocation, to: $0.coordinate)
                    < distance(from: userLocation, to: $1.coordinate)
            }
            .prefix(regionCap)
            .map { $0 }
    }

    /// Called when iOS reports the user crossed a geofence.
    /// Decide if the kind of cross matches what the user wanted, and fire.
    private func handleTransition(id: UUID, transition: RegionTransition) {
        // Look up the trigger. If we don't know about this id (race condition),
        // just ignore it.
        guard let trigger = activeTriggers[id] else { return }

        // Match the cross direction with what the user wanted.
        let kind: TriggerType
        switch (trigger.triggerType, transition) {
        case (.arriving, .enter): kind = .arriving
        case (.leaving, .exit): kind = .leaving
        default: return
        }

        // Don't fire the same trigger twice within 60 seconds.
        guard !isDebounced(trigger) else { return }

        emit(triggerId: id, kind: kind)
    }

    private func emit(triggerId: UUID, kind: TriggerType) {
        let event = GeofenceEvent(triggerId: triggerId, kind: kind, timestamp: Date())
        print("Geofence fired: \(kind)")
        onEvent?(event)
    }

    /// Has this trigger already fired in the last `debounceWindow` seconds?
    private func isDebounced(_ trigger: MonitoredTrigger) -> Bool {
        guard let last = trigger.lastTriggeredAt else { return false }
        return Date().timeIntervalSince(last) < debounceWindow
    }

    /// Is the user currently inside this trigger's circle?
    private func isInside(_ location: LocationCoordinate, trigger: MonitoredTrigger) -> Bool {
        distance(from: location, to: trigger.coordinate) <= trigger.radius
    }

    /// Distance in metres between two lat/long points.
    /// Uses the standard "haversine" formula for great-circle distance on a sphere.
    /// Accurate to within a few metres anywhere on Earth — plenty for geofencing.
    private func distance(from a: LocationCoordinate, to b: LocationCoordinate) -> Double {
        let earthRadius: Double = 6_371_000
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2)
              + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(h), sqrt(1 - h))
        return earthRadius * c
    }
}
