
import Foundation

final class GeofenceCoordinator {
    // Called whenever a geofence event should fire a reminder.
    var onEvent: ((GeofenceEvent) -> Void)?

    private let monitor: any RegionMonitoring
    private let regionCap: Int
    private let debounceWindow: TimeInterval

    // Lookup table: region id → trigger info. Used when an event fires so we know which trigger it belongs to.
    private var activeTriggers: [UUID: MonitoredTrigger] = [:]
    private var lastTriggeredAtByReminderTriggerId: [UUID: Date] = [:]

    init(
        monitor: any RegionMonitoring,
        regionCap: Int = 20,
        debounceWindow: TimeInterval = 60
    ) {
        self.monitor = monitor
        self.regionCap = regionCap
        self.debounceWindow = debounceWindow

        // Wire the monitor's "something happened" callback to our handler. [weak self] avoids a memory leak if the coordinator is destroyed.
        monitor.onRegionTransition = { [weak self] id, transition in
            self?.handleTransition(id: id, transition: transition)
        }
    }

    // Replace the active set of geofences. Call this whenever the set of reminders changes or the user moves significantly.
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
        for trigger in selected where toStart.contains(trigger.regionId) {
            print("starting monitoring for trigger: \(trigger.regionId)")
            print("Radius: \(trigger.radius)")
            print("Coordinate: \(trigger.coordinate.latitude), \(trigger.coordinate.longitude)")
            monitor.startMonitoring(
                id: trigger.regionId,
                coordinate: trigger.coordinate,
                radius: trigger.radius
            )
        }

        // Update our lookup table.
        activeTriggers = Dictionary(uniqueKeysWithValues: selected.map { ($0.regionId, $0) })

        // Cold-start arrivals fire immediately when the user is already inside.
        
        print("User Location Exists: \(userLocation != nil)")
        
        guard let userLocation else {
            print("No user location available")
            return }
        
        print("Current user location:-s")
        print("Current Latitude: ", userLocation.latitude)
        print("Current Longitude", userLocation.longitude)
        
        for trigger in selected {
            guard trigger.triggerType == .arriving else { continue }
            if isInside(userLocation, trigger: trigger), !isDebounced(trigger) {
                print("User is inside trigger region")
                print("Emitting cold-start Arrival")
                emit(triggerId: trigger.reminderTriggerId, kind: .arriving)
            }
        }
    }

    // Pick the closest triggers when iOS cannot monitor them all.
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

    // Called when iOS reports the user crossed a geofence. Decide if the kind of cross matches what the user wanted, and fire.
    private func handleTransition(id: UUID, transition: RegionTransition) {
        // Look up the trigger. If we don't know about this id (race condition), just ignore it.
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

        emit(triggerId: trigger.reminderTriggerId, kind: kind)
    }

    private func emit(triggerId: UUID, kind: TriggerType) {
        lastTriggeredAtByReminderTriggerId[triggerId] = Date()
        let event = GeofenceEvent(triggerId: triggerId, kind: kind, timestamp: Date())
        print("Geofence fired: \(kind)")
        onEvent?(event)
    }

    // Has this trigger already fired in the last `debounceWindow` seconds?
    private func isDebounced(_ trigger: MonitoredTrigger) -> Bool {
        let last = lastTriggeredAtByReminderTriggerId[trigger.reminderTriggerId] ?? trigger.lastTriggeredAt
        guard let last else { return false }
        return Date().timeIntervalSince(last) < debounceWindow
    }

    // Is the user currently inside this trigger's circle?
    private func isInside(_ location: LocationCoordinate, trigger: MonitoredTrigger) -> Bool {
        distance(from: location, to: trigger.coordinate) <= trigger.radius
    }

    // Haversine distance in metres between two coordinates.
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
