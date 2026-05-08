//
//  contextReminderApp.swift
//  contextReminder
//

import SwiftUI
import Combine

//
//  All stateful objects are created ONCE here and passed down.
//  The critical rule: never create a CoreLocationProvider in two places —
//  the GeofenceCoordinator and the UI must share the exact same instance.
//

fileprivate final class AppState: ObservableObject {
    // SwiftUI automatically provides `objectWillChange` for ObservableObject,
    // so we don't need to declare it manually.

    let locationProvider = CoreLocationProvider()
    let placeStore       = JSONPlaceStore()
    let reminderStore    = JSONReminderStore()
    let poiDiscovery: any POIDiscovering = MKLocalPOIDiscovery()
    let addressSearcher: any AddressSearching = MKLocalAddressSearcher()
    let geocoder: any Geocoding = CLGeocoder_Geocoder()

    let geofenceCoordinator: GeofenceCoordinator
    let triggerEngine: TriggerEngine

    init() {
        // Wire coordinator to the SAME locationProvider that the UI observes.
        geofenceCoordinator = GeofenceCoordinator(monitor: locationProvider)
        triggerEngine = TriggerEngine(
            reminderStore: reminderStore,
            placeStore:    placeStore,
            location:      locationProvider,
            coordinator:   geofenceCoordinator,
            poiDiscovery:  poiDiscovery
        )
    }
}

@main
struct contextReminderApp: App {
    @StateObject private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView(app: app)
        }
    }
}

// MARK: - RootView
// Separated so `.onChange` has a concrete ObservableObject to watch.

struct RootView: View {
    @ObservedObject fileprivate var app: AppState
    // Mirror the auth state locally so .animation reacts to it.
    @State private var auth: LocationAuthorization = .notDetermined

    var body: some View {
        Group {
            if auth == .notDetermined{
                LocationPermissionView(locationProvider: app.locationProvider)
            } else {
                MainTabView(app: app)
                    .onAppear {
                        // Returning user — start the engine immediately.
                        Task { await app.triggerEngine.start() }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: auth)
        .onAppear {
            auth = app.locationProvider.authorization
        }
        .onReceive(app.locationProvider.$authorization) { newAuth in
            auth = newAuth
            // Chain: foreground granted → ask for Always straight away.
            if newAuth == .foregroundOnly {
                app.locationProvider.requestAlwaysAuthorization()
            }
            // Fully authorised → boot the trigger engine.
            if newAuth == .full {
                Task { await app.triggerEngine.start() }
            }
        }
    }
}

// MARK: - MainTabView

struct MainTabView: View {
    fileprivate let app: AppState

    var body: some View {
        TabView {
            RemindersView(viewModel: remindersViewModel)
                .tabItem { Label("Reminders", systemImage: "bell") }

            PlacesLibraryView(viewModel: placesLibraryViewModel)
                .tabItem { Label("Places", systemImage: "list.bullet") }

            MapScreenView(viewModel: mapScreenViewModel)
                .tabItem { Label("Map", systemImage: "map") }

            #if DEBUG
            DebugScreenView(
                locationProvider: app.locationProvider,
                placeStore:       app.placeStore,
                triggerEngine:    app.triggerEngine
            )
            .tabItem { Label("Debug", systemImage: "ladybug") }
            #endif
        }
    }

    private var placesLibraryViewModel: PlacesLibraryViewModel {
        PlacesLibraryViewModel(
            store:    app.placeStore,
            location: app.locationProvider,
            searcher: app.addressSearcher,
            geocoder: app.geocoder
        )
    }

    private var mapScreenViewModel: MapScreenViewModel {
        MapScreenViewModel(
            store:        app.placeStore,
            location:     app.locationProvider,
            poiDiscovery: app.poiDiscovery
        )
    }

    private var remindersViewModel: RemindersViewModel {
        RemindersViewModel(
            reminderStore: app.reminderStore,
            placeStore:    app.placeStore
        )
    }
}
