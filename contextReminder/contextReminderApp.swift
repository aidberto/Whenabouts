//
//  contextReminderApp.swift
//  contextReminder
//

import SwiftUI

enum AppTab: Hashable {
    case reminders
    case places
    case map
    case debug
}

@main
struct contextReminderApp: App {
    // The single saved-Places store, kept alive for the whole app session.
    @StateObject private var placeStore = JSONPlaceStore()
    @StateObject private var reminderStore = JSONReminderStore()

    // Watches the user's location and exposes auth state to the rest of the app.
    @StateObject private var locationProvider = CoreLocationProvider()
    @State private var selectedTab: AppTab = .reminders

    // Helpers for the Place creation sheet (address search, reverse geocoding,
    // POI lookup). Plain `let` because they have no state of their own.
    private let addressSearcher: any AddressSearching = MKLocalAddressSearcher()
    private let geocoder: any Geocoding = CLGeocoder_Geocoder()
    private let poiDiscovery: any POIDiscovering = MKLocalPOIDiscovery()

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                RemindersView(viewModel: remindersViewModel, selectedTab: $selectedTab)
                    .tabItem { Label("Reminders", systemImage: "bell") }
                    .tag(AppTab.reminders)

                PlacesLibraryView(viewModel: placesLibraryViewModel, selectedTab: $selectedTab)
                    .tabItem { Label("Places", systemImage: "list.bullet") }
                    .tag(AppTab.places)

                MapScreenView(viewModel: mapScreenViewModel, selectedTab: $selectedTab)
                    .tabItem { Label("Map", systemImage: "map") }
                    .tag(AppTab.map)

                #if DEBUG
                // Debug tab only appears in development builds, never in release.
                DebugScreenView(
                    locationProvider: locationProvider,
                    placeStore: placeStore
                )
                .tabItem { Label("Debug", systemImage: "ladybug") }
                .tag(AppTab.debug)
                #endif
            }
            .onAppear {
                // Ask for location permission on first launch so the app is
                // ready to use straight away.
                if locationProvider.authorization == .notDetermined {
                    locationProvider.requestWhenInUseAuthorization()
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
