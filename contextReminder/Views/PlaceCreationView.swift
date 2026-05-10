//
//  PlaceCreationView.swift
//  contextReminder
//
//  The sheet shown when the user creates or edits a Place.
//  Has three picker modes for choosing a coordinate:
//    - Current  - snap to wherever the user is right now
//    - Search   - type an address, pick from suggestions
//    - Map      - drag a map until the centre pin is over the right spot
//

import SwiftUI
import MapKit

struct PlaceCreationView: View {
    @StateObject var viewModel: PlaceCreationViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mapCameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            ZStack {
                paperBackground

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        Text(viewModel.isEditing ? "Edit place" : "Add new place")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(Color(red: 0.24, green: 0.19, blue: 0.15))
                            .padding(.top, 8)

                        detailsSection
                        pickerSection
                        modeContentSection

                        if let error = viewModel.saveError {
                            Text(error)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 0.62, green: 0.12, blue: 0.10))
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(Color(red: 0.18, green: 0.16, blue: 0.13))
                            .frame(width: 48, height: 42)
                            .background(.white.opacity(0.58), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if viewModel.save() { dismiss() }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundStyle(viewModel.canSave ? Color(red: 0.18, green: 0.16, blue: 0.13) : .secondary.opacity(0.42))
                            .frame(width: 48, height: 42)
                            .background(.white.opacity(viewModel.canSave ? 0.58 : 0.42), in: Capsule())
                    }
                    .disabled(!viewModel.canSave)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Save")
                }
            }
            .onAppear { syncMapCamera() }
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            formSectionTitle("PLACE NAME")

            TextField("University", text: $viewModel.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color(red: 0.18, green: 0.15, blue: 0.12))
                .textInputAutocapitalization(.words)
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.black.opacity(0.04), lineWidth: 1)
                )

            formSectionTitle("WHAT KIND OF PLACE?")

            LazyVGrid(columns: tileColumns, spacing: 10) {
                ForEach(PlaceType.allCases) { type in
                    typeTile(type)
                }
            }
        }
    }

    private var pickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            formSectionTitle("HOW SHOULD WE FIND IT?")

            HStack(spacing: 10) {
                ForEach(PlaceCreationViewModel.PickerMode.allCases) { mode in
                    pickerModeButton(mode)
                }
            }
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
        VStack(alignment: .leading, spacing: 12) {
            formSectionTitle("CURRENT LOCATION")

            switch viewModel.locationAuthorization {
            case .denied, .restricted:
                statusCard("Location access denied.")
                actionPill("Open Settings", systemImage: "gear") { viewModel.openSettings() }
            case .notDetermined:
                actionPill("Allow location access", systemImage: "location") {
                    viewModel.useCurrentLocation()
                }
            case .foregroundOnly, .full:
                actionPill("Use current location", systemImage: "location.fill") {
                    viewModel.useCurrentLocation()
                }
                if let coord = viewModel.coordinate {
                    statusCard(formatted(coord))
                } else {
                    statusCard("Acquiring location...")
                }
            }
        }
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            formSectionTitle("ADDRESS SEARCH")

            TextField("Search for a place", text: $viewModel.searchQuery)
                .font(.system(size: 16, weight: .semibold))
                .textInputAutocapitalization(.words)
                .padding(16)
                .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onSubmit { viewModel.performSearch() }

            actionPill("Search", systemImage: "magnifyingglass") {
                viewModel.performSearch()
            }
            .disabled(viewModel.searchQuery.trimmingCharacters(in: .whitespaces).isEmpty)

            if viewModel.searchResults.isEmpty {
                statusCard("No results yet.")
            } else {
                ForEach(viewModel.searchResults) { suggestion in
                    let isSelected = isSelectedSuggestion(suggestion)

                    Button {
                        viewModel.selectSuggestion(suggestion)
                    } label: {
                        HStack(spacing: 12) {
                            Text("📍")
                                .font(.system(size: 20))
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(color(for: viewModel.placeType).opacity(0.28)))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(suggestion.title)
                                    .font(.system(size: 15, weight: .heavy))
                                    .foregroundStyle(Color(red: 0.18, green: 0.15, blue: 0.12))
                                    .lineLimit(1)
                                Text(suggestion.subtitle)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isSelected ? color(for: viewModel.placeType).opacity(0.22) : .white.opacity(0.82))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isSelected ? color(for: viewModel.placeType).opacity(0.95) : .clear, lineWidth: 1.4)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            formSectionTitle("DROP A PIN")

            ZStack {
                Map(position: $mapCameraPosition)
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onMapCameraChange { context in
                        let center = context.region.center
                        viewModel.updatePinnedCoordinate(
                            LocationCoordinate(latitude: center.latitude, longitude: center.longitude)
                        )
                    }

                Image(systemName: "mappin")
                    .font(.title)
                    .foregroundStyle(Color(red: 0.62, green: 0.12, blue: 0.10))
                    .offset(y: -10)
                    .allowsHitTesting(false)
            }

            if let address = viewModel.pinnedAddress {
                statusCard(address)
            }
            if let coord = viewModel.coordinate {
                statusCard(formatted(coord))
            }
        }
    }

    private var paperBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.95, blue: 0.90),
                Color(red: 1.00, green: 0.98, blue: 0.94)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var tileColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: 2)
    }

    private func formSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .heavy))
            .tracking(0.9)
            .foregroundStyle(Color(red: 0.62, green: 0.58, blue: 0.51))
    }

    private func typeTile(_ type: PlaceType) -> some View {
        Button {
            viewModel.placeType = type
        } label: {
            HStack(spacing: 10) {
                Text(icon(for: type))
                    .font(.system(size: 19))
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(color(for: type).opacity(viewModel.placeType == type ? 0.50 : 0.30)))

                VStack(alignment: .leading, spacing: 1) {
                    Text(type.displayName)
                        .font(.system(size: 14, weight: .heavy))
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                    Text("place type")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.72))
                }

                Spacer(minLength: 0)
            }
            .foregroundStyle(Color(red: 0.18, green: 0.15, blue: 0.12))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 58)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(viewModel.placeType == type ? color(for: type).opacity(0.38) : .white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(viewModel.placeType == type ? color(for: type).opacity(0.95) : color(for: type).opacity(0.16), lineWidth: viewModel.placeType == type ? 1.4 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func pickerModeButton(_ mode: PlaceCreationViewModel.PickerMode) -> some View {
        let isSelected = viewModel.pickerMode == mode

        return Button {
            viewModel.pickerMode = mode
            syncMapCamera()
        } label: {
            VStack(spacing: 7) {
                Image(systemName: icon(for: mode))
                    .font(.system(size: 17, weight: .bold))
                Text(mode.displayName)
                    .font(.system(size: 12, weight: .heavy))
            }
            .foregroundStyle(isSelected ? .white : Color(red: 0.20, green: 0.17, blue: 0.13))
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color(red: 0.11, green: 0.10, blue: 0.08) : .white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.black.opacity(isSelected ? 0 : 0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func actionPill(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(red: 0.08, green: 0.10, blue: 0.05))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color(red: 0.78, green: 1.00, blue: 0.24))
                )
                .overlay(
                    Capsule()
                        .stroke(Color(red: 0.10, green: 0.10, blue: 0.08), lineWidth: 1.6)
                )
        }
        .buttonStyle(.plain)
    }

    private func statusCard(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func isSelectedSuggestion(_ suggestion: AddressSuggestion) -> Bool {
        guard let coordinate = viewModel.coordinate else { return false }

        return abs(coordinate.latitude - suggestion.coordinate.latitude) < 0.000001
            && abs(coordinate.longitude - suggestion.coordinate.longitude) < 0.000001
    }

    private func icon(for mode: PlaceCreationViewModel.PickerMode) -> String {
        switch mode {
        case .currentLocation: return "location.fill"
        case .search: return "magnifyingglass"
        case .map: return "map"
        }
    }

    private func icon(for type: PlaceType) -> String {
        switch type {
        case .home: return "🏠"
        case .work: return "🎓"
        case .supermarket: return "🛒"
        case .pharmacy: return "💊"
        case .postOffice: return "📦"
        case .custom: return "📍"
        }
    }

    private func color(for type: PlaceType) -> Color {
        switch type {
        case .home:
            return Color(red: 1.00, green: 0.76, blue: 0.65)
        case .work:
            return Color(red: 0.68, green: 0.85, blue: 1.00)
        case .supermarket:
            return Color(red: 0.78, green: 1.00, blue: 0.24)
        case .pharmacy:
            return Color(red: 0.82, green: 0.72, blue: 1.00)
        case .postOffice:
            return Color(red: 1.00, green: 0.84, blue: 0.48)
        case .custom:
            return Color(red: 0.88, green: 0.94, blue: 0.82)
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

struct PlaceCreationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PlaceCreationView(
                viewModel: PlaceCreationViewModel(
                    store: InMemoryPlaceStore(),
                    location: ScriptedLocationProvider(),
                    searcher: StaticAddressSearcher(),
                    geocoder: StaticGeocoder(address: "Sample Street, Sydney")
                )
            )
            .previewDisplayName("Create - populated location")

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
            .previewDisplayName("Edit - existing place")
        }
    }
}
