//
//  MapScreenViewModel.swift
//  contextReminder
//
//  Powers the Map screen. Always shows the user's saved Places.
//  Searches for nearby places and optionally filters by category
//  (supermarket, pharmacy, post office). Also drives the map search bar.
//

import Foundation
import Combine
import MapKit

@MainActor
final class MapScreenViewModel: ObservableObject {
    /// Places returned by the most recent POI search.
    @Published private(set) var pois: [Place] = []

    /// Which category to look for. nil means show every discoverable category.
    @Published var selectedPOICategory: PlaceType?

    /// Current text in the map search bar.
    @Published var mapSearchQuery: String = ""

    /// Address suggestions returned from the map search.
    @Published private(set) var mapSearchResults: [AddressSuggestion] = []

    /// The coordinate the user picked from map search (used to fly the camera).
    @Published private(set) var mapSearchSelection: LocationCoordinate?

    private let store: any PlaceStore
    private let location: any LocationProviding
    private let poiDiscovery: any POIDiscovering
    private let searcher = MKLocalAddressSearcher()
    private var cancellables = Set<AnyCancellable>()
    private var mapSearchTask: Task<Void, Never>?

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

    // MARK: - POI search

    /// Run a POI search using the current filter and the user's current
    /// location. With no filter selected, all discoverable categories are shown.
    func refreshPOIs() async {
        guard let coordinate = location.currentCoordinate else {
            pois = []
            return
        }

        let categoriesToShow = selectedPOICategory.map { [$0] } ?? Self.discoverableCategories
        var discoveredPOIs: [Place] = []

        for category in categoriesToShow {
            let categoryPOIs = await poiDiscovery.nearestPOIs(
                category: category,
                near: coordinate,
                limit: 10
            )
            discoveredPOIs.append(contentsOf: categoryPOIs)
        }

        pois = discoveredPOIs
    }

    /// Pick a category and immediately refresh the POI list.
    func selectCategory(_ category: PlaceType?) {
        selectedPOICategory = category
        Task { await refreshPOIs() }
    }

    /// Async variant for views that need to react after the refreshed POIs exist.
    func selectCategoryAndRefresh(_ category: PlaceType?) async {
        selectedPOICategory = category
        await refreshPOIs()
    }

    // MARK: - Map address search

    /// Debounced search triggered as the user types in the map search bar.
    func scheduleMapSearch() {
        mapSearchTask?.cancel()
        let query = mapSearchQuery
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            mapSearchResults = []
            return
        }
        mapSearchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            await self.runMapSearch(query: query)
        }
    }

    private func runMapSearch(query: String) async {
        // Bias results toward the user's current area.
        if let coord = location.currentCoordinate {
            searcher.regionBias = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude),
                latitudinalMeters: 50_000,
                longitudinalMeters: 50_000
            )
        }
        mapSearchResults = await searcher.search(query: query)
    }

    /// User tapped a suggestion — record the coordinate so the view can fly
    /// the camera there, and clear the results list.
    func selectMapSearchResult(_ suggestion: AddressSuggestion) {
        mapSearchSelection = suggestion.coordinate
        mapSearchQuery = suggestion.title
        mapSearchResults = []
    }

    /// Dismiss the suggestion list without navigating anywhere.
    func clearMapSearch() {
        mapSearchTask?.cancel()
        mapSearchQuery = ""
        mapSearchResults = []
        mapSearchSelection = nil
    }
}
