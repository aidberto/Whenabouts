//
//  contextReminderApp.swift
//  contextReminder
//

import SwiftUI

@main
struct contextReminderApp: App {
    // The single saved-Places store, kept alive for the whole app session.
    @StateObject private var placeStore = JSONPlaceStore()
    @StateObject private var reminderStore = JSONReminderStore()

    // Watches the user's location and exposes auth state to the rest of the app.
    @StateObject private var locationProvider = CoreLocationProvider()

    // Helpers for the Place creation sheet (address search, reverse geocoding,
    // POI lookup). Plain `let` because they have no state of their own.
    private let addressSearcher: any AddressSearching = MKLocalAddressSearcher()
    private let geocoder: any Geocoding = CLGeocoder_Geocoder()
    private let poiDiscovery: any POIDiscovering = MKLocalPOIDiscovery()
    
    private let notificationManager = LocalNotificationManager.shared
    
    @State private var hasInitializedServices = false
    @State private var geofenceCoordinator: GeofenceCoordinator?
    @State private var reminderTriggerCoordinator: ReminderTriggerCoordinator?
    @State private var reminderMonitoringService: ReminderMonitoringService?
        
    var body: some Scene {
        WindowGroup {
            TabView {
                RemindersView(viewModel: remindersViewModel)
                    .tabItem { Label("Reminders", systemImage: "bell") }

                PlacesLibraryView(viewModel: placesLibraryViewModel)
                    .tabItem { Label("Places", systemImage: "list.bullet") }

                MapScreenView(viewModel: mapScreenViewModel)
                    .tabItem { Label("Map", systemImage: "map") }

                #if DEBUG
                // Debug tab only appears in development builds, never in release.
                DebugScreenView(
                    locationProvider: locationProvider,
                    placeStore: placeStore
                )
                .tabItem { Label("Debug", systemImage: "ladybug") }
                #endif
            }
            .onAppear {
                // Ask for location permission on first launch so the app is
                // ready to use straight away.
                
                guard !hasInitializedServices else {
                return
                }

                hasInitializedServices = true

                Task {
                _ = await notificationManager.requestPermission()
                }

                if locationProvider.authorization == .notDetermined {
                locationProvider.requestWhenInUseAuthorization()
                }

                let geofenceCoordinator = GeofenceCoordinator(
                monitor: locationProvider
                )

                let reminderTriggerCoordinator = ReminderTriggerCoordinator(
                reminderStore: reminderStore,
                notificationManager: notificationManager
                )

                let reminderMonitoringService = ReminderMonitoringService(
                reminderStore: reminderStore,
                geofenceCoordinator: geofenceCoordinator,
                locationProvider: locationProvider
                )

                geofenceCoordinator.onEvent = { event in
                reminderTriggerCoordinator.handleEvent(event)
                }

                self.geofenceCoordinator = geofenceCoordinator
                self.reminderTriggerCoordinator = reminderTriggerCoordinator
                self.reminderMonitoringService = reminderMonitoringService

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.reminderMonitoringService?.refreshMonitoring()
                }
            }
        }
    }

    // MARK: - View model factories

    private var placesLibraryViewModel: PlacesLibraryViewModel {
        PlacesLibraryViewModel(
            store: placeStore,
            location: locationProvider,
            searcher: addressSearcher,
            geocoder: geocoder
        )
    }

    private var mapScreenViewModel: MapScreenViewModel {
        MapScreenViewModel(
            store: placeStore,
            location: locationProvider,
            poiDiscovery: poiDiscovery
        )
    }

    private var remindersViewModel: RemindersViewModel {
        RemindersViewModel(
            reminderStore: reminderStore,
            placeStore: placeStore
        )
    }
    
}
