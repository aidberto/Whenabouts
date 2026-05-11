//
//  DebugScreenView.swift
//  contextReminder
//
//  Developer-only screen for inspecting what the location stack is doing:
//  permission state, current coordinate, monitored geofence circles, saved Places.
//
//  Only compiled in debug builds — `#if DEBUG` makes it disappear in release.
//

#if DEBUG
import SwiftUI

struct DebugScreenView: View {
    @ObservedObject var locationProvider: CoreLocationProvider
    @ObservedObject var placeStore: JSONPlaceStore
    @State private var notificationSimulationStatus = "Not run"

    var body: some View {
        NavigationStack {
            List {
                authorizationSection
                currentCoordinateSection
                monitoredRegionsSection
                notificationTestSection
                placesSection
            }
            .navigationTitle("Debug")
            .listStyle(.insetGrouped)
        }
    }

    private var notificationTestSection: some View {
        Section("Notification Test") {
            Button {
                simulateGeofenceNotification()
            } label: {
                Label("Simulate temporary reminder", systemImage: "location.circle")
            }

            Button {
                simulateFirstMonitoredRegionEnter()
            } label: {
                Label("Simulate first monitored region", systemImage: "bell.badge")
            }
            .disabled(locationProvider.monitoredRegionIds.isEmpty)

            Text(notificationSimulationStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Sections

    private var authorizationSection: some View {
        Section("Authorization") {
            row("State", locationProvider.authorization.label)
            row("Can monitor in background?",
                locationProvider.authorization.canMonitorInBackground ? "Yes" : "No")
        }
    }

    private var currentCoordinateSection: some View {
        Section("Current Location") {
            if let coord = locationProvider.currentCoordinate {
                row("Latitude", String(format: "%.6f", coord.latitude))
                row("Longitude", String(format: "%.6f", coord.longitude))
                row("Updated", Date().formatted(date: .omitted, time: .standard))
            } else {
                Text("No fix yet")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var monitoredRegionsSection: some View {
        Section("Monitored Regions (\(locationProvider.monitoredRegionIds.count))") {
            if locationProvider.monitoredRegionIds.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(locationProvider.monitoredRegionIds), id: \.self) { id in
                    monitoredRegionRow(id)
                }
            }
        }
    }

    private var placesSection: some View {
        Section("Saved Places (\(placeStore.places.count))") {
            if placeStore.places.isEmpty {
                Text("None")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(placeStore.places) { place in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name).font(.body)
                        Text("\(place.placeType.displayName) — \(formattedCoord(lat: place.latitude, lon: place.longitude))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// One row in the "Monitored Regions" list.
    /// Tries to match the region id back to a saved Place to show a friendly
    /// name. POI-discovered regions don't match anything saved, so we just
    /// show the raw id.
    private func monitoredRegionRow(_ id: UUID) -> some View {
        if let place = placeStore.places.first(where: { $0.id == id }) {
            return AnyView(
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name).font(.body)
                    Text("\(place.placeType.displayName) — \(formattedCoord(lat: place.latitude, lon: place.longitude))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            )
        } else {
            return AnyView(
                Text(id.uuidString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            )
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func formattedCoord(lat: Double, lon: Double) -> String {
        String(format: "%.5f, %.5f", lat, lon)
    }

    private func simulateGeofenceNotification() {
        notificationSimulationStatus = "Requesting notification permission..."

        Task {
            let notificationManager = LocalNotificationManager.shared
            let didGrantPermission = await notificationManager.requestPermission()
            let alreadyAuthorized = await notificationManager.notificationPermissionStatus()
            let isAuthorized = didGrantPermission || alreadyAuthorized

            guard isAuthorized else {
                notificationSimulationStatus = "Notifications are not authorized."
                return
            }

            let triggerId = UUID()
            let debugPlace = Place(
                name: "Debug Geofence",
                placeType: .custom,
                latitude: locationProvider.currentCoordinate?.latitude ?? -33.8837,
                longitude: locationProvider.currentCoordinate?.longitude ?? 151.2006,
                radius: 150
            )
            let reminder = Reminder(
                title: "Geofence test fired",
                notes: "This came from the Debug screen geofence simulation.",
                category: .general,
                priority: .normal,
                trigger: ReminderTrigger(
                    id: triggerId,
                    triggerType: .arriving,
                    target: .place(debugPlace)
                )
            )

            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("debug-geofence-\(UUID().uuidString).json")
            let reminderStore = JSONReminderStore(fileURL: fileURL)
            reminderStore.add(reminder)

            let fakeMonitor = FakeRegionMonitor()
            let geofenceCoordinator = GeofenceCoordinator(
                monitor: fakeMonitor,
                debounceWindow: 0
            )
            let triggerCoordinator = ReminderTriggerCoordinator(
                reminderStore: reminderStore,
                notificationManager: notificationManager
            )

            geofenceCoordinator.onEvent = { event in
                triggerCoordinator.handleEvent(event)
            }
            geofenceCoordinator.setActiveTriggers(
                [
                    MonitoredTrigger(
                        id: triggerId,
                        coordinate: LocationCoordinate(
                            latitude: debugPlace.latitude,
                            longitude: debugPlace.longitude
                        ),
                        radius: debugPlace.radius,
                        triggerType: .arriving,
                        lastTriggeredAt: nil
                    )
                ],
                userLocation: nil
            )

            fakeMonitor.simulateTransition(triggerId, .enter)
            notificationSimulationStatus = "Simulated geofence enter. A local notification should appear."
        }
    }

    private func simulateFirstMonitoredRegionEnter() {
        guard let regionId = locationProvider.monitoredRegionIds.first else {
            notificationSimulationStatus = "No monitored regions available."
            return
        }

        notificationSimulationStatus = "Simulating monitored region enter..."

        Task {
            let notificationManager = LocalNotificationManager.shared
            _ = await notificationManager.requestPermission()

            locationProvider.onRegionTransition?(regionId, .enter)
            notificationSimulationStatus = "Sent enter event for \(regionId.uuidString)."
        }
    }
}

// MARK: - LocationAuthorization label helper

private extension LocationAuthorization {
    var label: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .foregroundOnly: return "Foreground Only"
        case .full: return "Full (Always)"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        }
    }
}

#endif
