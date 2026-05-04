//
//  PlaceCreationView.swift
//  contextReminder
//
//  The sheet shown when the user creates or edits a Place.
//  Has three picker modes for choosing a coordinate:
//    - Current  — snap to wherever the user is right now
//    - Search   — type an address, pick from suggestions
//    - Map      — drag a map until the centre pin is over the right spot
//

import SwiftUI
import MapKit

struct PlaceCreationView: View {
    @StateObject var viewModel: PlaceCreationViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mapCameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            Form {
                detailsSection
                pickerSection
                modeContentSection
                if let error = viewModel.saveError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Place" : "New Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if viewModel.save() { dismiss() }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .onAppear { syncMapCamera() }
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Name", text: $viewModel.name)
            Picker("Type", selection: $viewModel.placeType) {
                ForEach(PlaceType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            }
        }
    }

    private var pickerSection: some View {
        Section {
            Picker("Pick coordinate", selection: $viewModel.pickerMode) {
                ForEach(PlaceCreationViewModel.PickerMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.pickerMode) { _, _ in syncMapCamera() }
        }
    }

    @ViewBuilder
    private var modeContentSection: some View {
        switch viewModel.pickerMode {
        case .currentLocation:
            currentLocationSection
        case .search:
            searchSection
        case .map:
            mapSection
        }
    }

    private var currentLocationSection: some View {
        Section("Current Location") {
            switch viewModel.locationAuthorization {
            case .denied, .restricted:
                Text("Location access denied.")
                    .foregroundStyle(.secondary)
                Button("Open Settings") { viewModel.openSettings() }
            case .notDetermined:
                Button("Allow location access") {
                    viewModel.useCurrentLocation()
                }
            case .foregroundOnly, .full:
                Button("Use current location") {
                    viewModel.useCurrentLocation()
                }
                if let coord = viewModel.coordinate {
                    Text(formatted(coord)).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Acquiring location…").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var searchSection: some View {
        Section("Address Search") {
            TextField("Search for a place", text: $viewModel.searchQuery)
                .onSubmit { viewModel.performSearch() }
            Button("Search") { viewModel.performSearch() }
                .disabled(viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            if viewModel.searchResults.isEmpty {
                Text("No results yet.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.searchResults) { suggestion in
                    Button {
                        viewModel.selectSuggestion(suggestion)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(suggestion.title).foregroundStyle(.primary)
                            Text(suggestion.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var mapSection: some View {
        Section("Map") {
            ZStack {
                Map(position: $mapCameraPosition)
                    .frame(height: 240)
                    .onMapCameraChange { context in
                        let center = context.region.center
                        viewModel.updatePinnedCoordinate(
                            LocationCoordinate(latitude: center.latitude, longitude: center.longitude)
                        )
                    }
                Image(systemName: "mappin")
                    .font(.title)
                    .foregroundStyle(.red)
                    .offset(y: -10)
                    .allowsHitTesting(false)
            }
            if let address = viewModel.pinnedAddress {
                Text(address).font(.caption).foregroundStyle(.secondary)
            }
            if let coord = viewModel.coordinate {
                Text(formatted(coord)).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func syncMapCamera() {
        if let coord = viewModel.coordinate ?? viewModel.currentLocationCoordinate {
            mapCameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: coord.latitude,
                        longitude: coord.longitude
                    ),
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            )
        }
    }

    private func formatted(_ coord: LocationCoordinate) -> String {
        String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
    }
}

#Preview("Create — populated location") {
    PlaceCreationView(
        viewModel: PlaceCreationViewModel(
            store: InMemoryPlaceStore(),
            location: ScriptedLocationProvider(),
            searcher: StaticAddressSearcher(),
            geocoder: StaticGeocoder(address: "Sample Street, Sydney")
        )
    )
}

#Preview("Edit — existing place") {
    PlaceCreationView(
        viewModel: PlaceCreationViewModel(
            store: InMemoryPlaceStore(),
            location: ScriptedLocationProvider(),
            searcher: StaticAddressSearcher(),
            geocoder: StaticGeocoder(),
            editing: Place(
                name: "Home",
                placeType: .home,
                latitude: -33.8688,
                longitude: 151.2093
            )
        )
    )
}
