
import Foundation
import Combine

@MainActor
final class MapScreenViewModel: ObservableObject {
    // Places returned by the most recent POI search.
    @Published private(set) var pois: [Place] = []
    @Published private(set) var searchResults: [AddressSuggestion] = []

    // Which category to look for. nil means show every discoverable category.
    @Published var selectedPOICategory: PlaceType?

    private let store: any PlaceStore
    private let location: any LocationProviding
    private let searcher: any AddressSearching
    private let geocoder: any Geocoding
    private let poiDiscovery: any POIDiscovering
    private var cancellables = Set<AnyCancellable>()
    private var searchTask: Task<Void, Never>?

    // Categories the picker offers. Personal categories (home, work, custom) are excluded because Apple's catalogue doesn't know about them.
    static let discoverableCategories: [PlaceType] = [.supermarket, .pharmacy, .postOffice]

    // Saved Places, read straight from the store.
    var places: [Place] { store.places }

    // Latest known user coordinate (may be nil if no permission yet).
    var currentCoordinate: LocationCoordinate? { location.currentCoordinate }

    // Current location permission state — used to decide whether the blue user-location dot should appear on the map.
    var authorization: LocationAuthorization { location.authorization }

    init(
        store: any PlaceStore,
        location: any LocationProviding,
        searcher: any AddressSearching,
        geocoder: any Geocoding,
        poiDiscovery: any POIDiscovering
    ) {
        self.store = store
        self.location = location
        self.searcher = searcher
        self.geocoder = geocoder
        self.poiDiscovery = poiDiscovery

        // Tell SwiftUI to redraw when either the saved Places or the user's location changes.
        store.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        location.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // Run a POI search using the current filter and the user's current location. With no filter selected, all discoverable categories are shown.
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

    // Pick a category and immediately refresh the POI list.
    func selectCategory(_ category: PlaceType?) {
        selectedPOICategory = category
        Task { await refreshPOIs() }
    }

    // Async variant for views that need to react after the refreshed POIs exist.
    func selectCategoryAndRefresh(_ category: PlaceType?) async {
        selectedPOICategory = category
        await refreshPOIs()
    }

    func performSearch(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        searchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(220))
            if Task.isCancelled { return }
            let results = await self.searcher.search(query: trimmed)
            if Task.isCancelled { return }
            self.searchResults = results
        }
    }

    func clearSearchResults() {
        searchTask?.cancel()
        searchResults = []
    }

    func makeCreationViewModel(from suggestion: AddressSuggestion) -> PlaceCreationViewModel {
        PlaceCreationViewModel(
            store: store,
            location: location,
            searcher: searcher,
            geocoder: geocoder,
            seedSuggestion: suggestion
        )
    }
}
