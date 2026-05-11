//
//  PlaceCreationViewModel.swift
//  contextReminder
//
//  Powers the create/edit Place sheet. Handles the three picker modes:
//  current location, address search, and map pin drop. Same view model
//  used for both creating new Places and editing existing ones.
//

import Foundation
import Combine

@MainActor
final class PlaceCreationViewModel: ObservableObject {

    /// The three ways the user can pick a coordinate.
    enum PickerMode: String, CaseIterable, Identifiable {
        case currentLocation
        case search
        case map

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .currentLocation: return "Current"
            case .search: return "Search"
            case .map: return "Map"
            }
        }
    }

    // Form fields the user can edit.
    @Published var name: String = ""
    @Published var placeType: PlaceType = .custom
    @Published var pickerMode: PickerMode = .currentLocation
    @Published var coordinate: LocationCoordinate?
    @Published var searchQuery: String = ""

    // Read-only state shown to the view.
    @Published private(set) var searchResults: [AddressSuggestion] = []
    @Published private(set) var pinnedAddress: String?
    @Published private(set) var saveError: String?

    private let store: any PlaceStore
    private let location: any LocationProviding
    private let searcher: any AddressSearching
    private let geocoder: any Geocoding

    /// If we're editing an existing Place, its id. Nil if creating a new one.
    private let editingId: UUID?

    private var locationCancellable: AnyCancellable?
    private var searchTask: Task<Void, Never>?
    private var geocodeTask: Task<Void, Never>?

    init(
        store: any PlaceStore,
        location: any LocationProviding,
        searcher: any AddressSearching,
        geocoder: any Geocoding,
        editing: Place? = nil,
        seedSuggestion: AddressSuggestion? = nil
    ) {
        self.store = store
        self.location = location
        self.searcher = searcher
        self.geocoder = geocoder

        if let existing = editing {
            // Pre-fill the form with the existing Place's values.
            self.editingId = existing.id
            self.name = existing.name
            self.placeType = existing.placeType
            self.coordinate = LocationCoordinate(
                latitude: existing.latitude,
                longitude: existing.longitude
            )
            self.pickerMode = .map
        } else if let suggestion = seedSuggestion {
            self.editingId = nil
            self.name = suggestion.title
            self.coordinate = suggestion.coordinate
            self.searchQuery = suggestion.title
            self.searchResults = [suggestion]
            self.pinnedAddress = suggestion.subtitle.isEmpty ? nil : suggestion.subtitle
            self.pickerMode = .search
        } else {
            // New Place — start blank, optionally seed coordinate with current location.
            self.editingId = nil
            self.coordinate = location.currentCoordinate
        }

        // Re-render when the user's location updates (so the "Current" mode
        // reflects new coordinates as the GPS gets a better fix).
        locationCancellable = location.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.objectWillChange.send()
            }
        }
    }

    /// True when the user is editing an existing Place (vs creating a new one).
    var isEditing: Bool { editingId != nil }

    /// True when the form has enough info to save.
    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && coordinate != nil
    }

    var currentLocationCoordinate: LocationCoordinate? {
        location.currentCoordinate
    }

    var locationAuthorization: LocationAuthorization {
        location.authorization
    }

    /// Set the coordinate to wherever the user is right now.
    /// Triggers the permission prompt if needed; shows an error if denied.
    func useCurrentLocation() {
        if location.authorization == .notDetermined {
            location.requestWhenInUseAuthorization()
            return
        }
        if location.authorization == .denied || location.authorization == .restricted {
            saveError = "Location access denied. Open Settings to enable it."
            return
        }
        coordinate = location.currentCoordinate
    }

    func openSettings() {
        location.openSettings()
    }

    /// User tapped a search result — fill in the coordinate and (if name is empty)
    /// the suggested name.
    func selectSuggestion(_ suggestion: AddressSuggestion) {
        coordinate = suggestion.coordinate
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            name = suggestion.title
        }
    }

    /// Run an address search for the current query. Cancels any earlier
    /// in-flight search so only the latest result wins.
    func performSearch() {
        searchTask?.cancel()
        let query = searchQuery
        searchTask = Task { [weak self] in
            guard let self else { return }
            let results = await self.searcher.search(query: query)
            if Task.isCancelled { return }
            self.searchResults = results
        }
    }

    /// User panned the map — update the pinned coordinate and look up the
    /// address for it (so we can show "42 Smith St" under the pin).
    func updatePinnedCoordinate(_ value: LocationCoordinate) {
        coordinate = value
        geocodeTask?.cancel()
        geocodeTask = Task { [weak self] in
            guard let self else { return }
            let address = await self.geocoder.address(for: value)
            if Task.isCancelled { return }
            self.pinnedAddress = address
        }
    }

    /// Save the Place. Creates a new one or updates the existing one
    /// (depending on whether `editingId` is set). Returns true on success
    /// so the view can dismiss the sheet.
    func save() -> Bool {
        guard let coordinate, canSave else { return false }
        let trimmed = name.trimmingCharacters(in: .whitespaces)

        if let editingId {
            let updated = Place(
                id: editingId,
                name: trimmed,
                placeType: placeType,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            store.update(updated)
        } else {
            let new = Place(
                name: trimmed,
                placeType: placeType,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            store.add(new)
        }
        return true
    }
}
