//
//  TriggerEngine.swift
//  contextReminder
//
//  The brain of the app. Sits between the reminder/place stores, the
//  GeofenceCoordinator, and the NotificationService.
//
//  What it does:
//    1. Whenever reminders or places change, rebuilds the set of geofence
//       circles the coordinator should watch.
//    2. For "any supermarket" style reminders (placeType targets), it runs a
//       POI search near the user and creates geofences for those results.
//    3. When the GeofenceCoordinator fires an event, it matches the event
//       back to a reminder and asks NotificationService to fire.
//    4. Keeps the geofence list fresh when the user's location changes
//       significantly (>500m), swapping in the 20 closest circles.
//

import Foundation
import Combine

@MainActor
final class TriggerEngine: ObservableObject {

    // MARK: - Dependencies

    private let reminderStore: any ReminderStore
    private let placeStore: any PlaceStore
    private let location: any LocationProviding
    private let coordinator: GeofenceCoordinator
    private let poiDiscovery: any POIDiscovering
    private let notifications: NotificationService

    // MARK: - Internal state

    /// Maps a MonitoredTrigger id back to the Reminder it belongs to.
    /// Used when an event fires so we know which reminder to notify.
    private var triggerToReminder: [UUID: Reminder] = [:]

    /// Last location we refreshed POI geofences from.
    /// We only re-query when the user moves >500m.
    private var lastRefreshLocation: LocationCoordinate?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        reminderStore: any ReminderStore,
        placeStore: any PlaceStore,
        location: any LocationProviding,
        coordinator: GeofenceCoordinator,
        poiDiscovery: any POIDiscovering,
        notifications: NotificationService? = nil
    ) {
        self.reminderStore = reminderStore
        self.placeStore = placeStore
        self.location = location
        self.coordinator = coordinator
        self.poiDiscovery = poiDiscovery
        self.notifications = notifications ?? .shared

        // Wire the coordinator's event callback.
        coordinator.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleGeofenceEvent(event)
            }
        }

        // Re-build geofences whenever reminders or places change.
        reminderStore.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in await self?.refresh() }
            }
            .store(in: &cancellables)

        placeStore.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in await self?.refresh() }
            }
            .store(in: &cancellables)

        // Re-build geofences (with fresh POI search) when the user moves >500m.
        location.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in await self?.refreshIfMoved() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public

    /// Call once at app start, after notification permission is granted.
    func start() async {
        await notifications.requestAuthorization()
        await refresh()
    }

    // MARK: - Refresh

    /// Rebuild the full set of geofences from current reminders + places + POIs.
    func refresh() async {
        let reminders = reminderStore.reminders.filter { !$0.isCompleted }
        let places = placeStore.places
        let userLocation = location.currentCoordinate

        var triggers: [MonitoredTrigger] = []
        var mapping: [UUID: Reminder] = [:]

        for reminder in reminders {
            let newTriggers = await triggersFor(
                reminder: reminder,
                savedPlaces: places,
                userLocation: userLocation
            )
            for t in newTriggers {
                mapping[t.id] = reminder
            }
            triggers.append(contentsOf: newTriggers)
        }

        triggerToReminder = mapping
        coordinator.setActiveTriggers(triggers, userLocation: userLocation)

        if let loc = userLocation {
            lastRefreshLocation = loc
        }
    }

    /// Only refresh if the user has moved more than 500m since last refresh.
    private func refreshIfMoved() async {
        guard let current = location.currentCoordinate else { return }
        if let last = lastRefreshLocation,
           haversineDistance(from: last, to: current) < 500 { return }
        await refresh()
    }

    // MARK: - Build triggers for one reminder

    private func triggersFor(
        reminder: Reminder,
        savedPlaces: [Place],
        userLocation: LocationCoordinate?
    ) async -> [MonitoredTrigger] {

        switch reminder.trigger.target {

        case .place(let place):
            // Fixed saved place — one geofence circle.
            let t = MonitoredTrigger(
                id: reminder.trigger.id,
                coordinate: LocationCoordinate(latitude: place.latitude, longitude: place.longitude),
                radius: max(place.radius, 100),
                triggerType: reminder.trigger.triggerType,
                lastTriggeredAt: nil
            )
            return [t]

        case .placeType(let type):
            // "Any supermarket" — find the nearest ones and make a circle for each.
            guard let userLocation else { return [] }

            let pois = await poiDiscovery.nearestPOIs(
                category: type,
                near: userLocation,
                limit: 5          // max 5 per reminder to leave room for others
            )

            return pois.map { poi in
                MonitoredTrigger(
                    id: UUID(),    // fresh id each refresh — coordinator handles diff
                    coordinate: LocationCoordinate(latitude: poi.latitude, longitude: poi.longitude),
                    radius: 150,   // 150m radius around each discovered store
                    triggerType: reminder.trigger.triggerType,
                    lastTriggeredAt: nil
                )
            }
        }
    }

    // MARK: - Handle event

    private func handleGeofenceEvent(_ event: GeofenceEvent) {
        guard let reminder = triggerToReminder[event.triggerId] else {
            print("TriggerEngine: no reminder for trigger \(event.triggerId)")
            return
        }

        guard !reminder.isCompleted else { return }

        let description = triggerDescription(for: reminder, event: event)
        notifications.fire(reminder: reminder, triggerDescription: description)
    }

    private func triggerDescription(for reminder: Reminder, event: GeofenceEvent) -> String {
        let action = event.kind == .arriving ? "Arriving at" : "Leaving"
        switch reminder.trigger.target {
        case .place(let place):
            return "\(action) \(place.name)"
        case .placeType(let type):
            return "\(action) a \(type.displayName.lowercased())"
        }
    }

    // MARK: - Distance helper

    private func haversineDistance(from a: LocationCoordinate, to b: LocationCoordinate) -> Double {
        let R: Double = 6_371_000
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat/2)*sin(dLat/2) + cos(lat1)*cos(lat2)*sin(dLon/2)*sin(dLon/2)
        return R * 2 * atan2(sqrt(h), sqrt(1-h))
    }
}

