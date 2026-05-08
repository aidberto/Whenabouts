//
//  MapScreenViewModel.swift
//  contextReminder
//
//  Powers the Map screen. Always shows the user's saved Places.
//  Optionally searches for nearby places of a category (supermarket,
//  pharmacy, post office) and shows those too.
//

import Foundation
import Combine

@MainActor
final class MapScreenViewModel: ObservableObject {
    /// Places returned by the most recent POI search. Empty when no category
    /// is selected.
    @Published private(set) var pois: [Place] = []

    /// Which category to look for. nil means "don't show POIs".
    @Published var selectedPOICategory: PlaceType?

    private let store: any PlaceStore
    private let location: any LocationProviding
    private let poiDiscovery: any POIDiscovering
    private var cancellables = Set<AnyCancellable>()

    /// Categories the picker offers. Personal categories (home, work, custom)
    /// are excluded because Apple's catalogue doesn't know about them.
    static let discoverableCategories: [PlaceType] = [.supermarket, .pharmacy, .postOffice]

    /// Saved Places, read straight from the store.
    var places: [Place] { store.places }

    /// Latest known user coordinate (may be nil if no permission yet).
    var currentCoordinate: LocationCoordinate? { location.currentCoordinate }

    /// Current location permission state — used to decide whether the blue
    /// user-location dot should appear on the map.
    var authorization: LocationAuthorization { location.authorization }

    init(
        store: any PlaceStore,
        location: any LocationProviding,
        poiDiscovery: any POIDiscovering
    ) {
        self.store = store
        self.location = location
        self.poiDiscovery = poiDiscovery

        // Tell SwiftUI to redraw when either the saved Places or the user's
        // location changes.
        store.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        location.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// Run a POI search using the currently-selected category and the user's
    /// current location. Clears the result list if either is missing.
    func refreshPOIs() async {
        guard
            let category = selectedPOICategory,
            let coordinate = location.currentCoordinate
        else {
            pois = []
            return
        }
        pois = await poiDiscovery.nearestPOIs(
            category: category,
            near: coordinate,
            limit: 10
        )
    }

    /// Pick a category and immediately refresh the POI list.
    func selectCategory(_ category: PlaceType?) {
        selectedPOICategory = category
        Task { await refreshPOIs() }
    }
}
