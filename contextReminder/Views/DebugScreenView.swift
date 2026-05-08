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
    var triggerEngine: TriggerEngine? = nil

    @State private var refreshMessage: String? = nil

    var body: some View {
        NavigationStack {
            List {
                authorizationSection
                currentCoordinateSection
                monitoredRegionsSection
                placesSection
                if triggerEngine != nil {
                    triggerEngineSection
                }
            }
            .navigationTitle("Debug")
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Sections

    private var authorizationSection: some View {
        Section("Authorization") {
            row("State", locationProvider.authorization.label)
            row("Can monitor in background?",
                locationProvider.authorization.canMonitorInBackground ? "Yes" : "No")

            if locationProvider.authorization == .foregroundOnly {
                Button("Upgrade to Always Allow") {
                    locationProvider.requestAlwaysAuthorization()
                }
                .foregroundStyle(.blue)
            }
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

    private var triggerEngineSection: some View {
        Section("Trigger Engine") {
            Button("Force Geofence Refresh") {
                Task {
                    await triggerEngine?.refresh()
                    refreshMessage = "Refreshed at \(Date().formatted(date: .omitted, time: .standard))"
                }
            }
            .foregroundStyle(.blue)

            if let msg = refreshMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Active geofences: \(locationProvider.monitoredRegionIds.count) / 20")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Tip: use a GPX file in the Simulator (Features → Location) or the Debug bar to simulate movement into a geofence.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Helpers

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

