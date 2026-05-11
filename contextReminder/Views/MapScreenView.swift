
import SwiftUI
import MapKit

struct MapScreenView: View {
    @StateObject var viewModel: MapScreenViewModel
    @Binding var selectedTab: AppTab

    // Where the map is currently looking. We move it to the user's location once we have one, otherwise it auto-fits to the pins.
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var searchQuery = ""
    @State private var selectedSearchResult: AddressSuggestion?
    @State private var creationViewModel: PlaceCreationViewModel?

    var body: some View {
        NavigationStack {
            mapCard
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { centreOnUserIfPossible() }
            .task {
                await viewModel.refreshPOIs()
                fitVisibleAnnotations()
            }
            .onChange(of: viewModel.currentCoordinate?.latitude) { _, _ in
                centreOnUserIfPossible()
                Task {
                    await viewModel.refreshPOIs()
                    fitVisibleAnnotations()
                }
            }
            .onChange(of: viewModel.pois.count) { _, _ in
                fitVisibleAnnotations()
            }
            .onChange(of: searchQuery) { _, newValue in
                viewModel.performSearch(query: newValue)
            }
            .safeAreaInset(edge: .bottom) {
                quickAddBar
            }
            .toolbar(.hidden, for: .tabBar)
        }
        .sheet(item: $creationViewModel) { vm in
            PlaceCreationView(viewModel: vm)
        }
    }

    // MARK: - Map content

    private var mapCard: some View {
        ZStack(alignment: .top) {
            mapContent
                .mapStyle(
                    .standard(
                        elevation: .flat,
                        emphasis: .muted,
                        pointsOfInterest: .excludingAll,
                        showsTraffic: false
                    )
                )
                .ignoresSafeArea()

            mapSearchAndFilters
                .padding(.top, 58)
                .padding(.horizontal, 14)
        }
    }

    // The Map itself. Three layers: saved Places, discovered POIs, user dot.
    private var mapContent: some View {
        Map(position: $cameraPosition) {
            ForEach(visibleSavedPlaces) { place in
                Annotation(place.name, coordinate: place.coordinate2D) {
                    pinView(for: place.placeType, dimmed: false)
                }
            }
            ForEach(viewModel.pois) { poi in
                Annotation(poi.name, coordinate: poi.coordinate2D) {
                    pinButton(for: suggestion(from: poi), type: poi.placeType, dimmed: true)
                }
            }
            if let selectedSearchResult {
                Annotation(selectedSearchResult.title, coordinate: selectedSearchResult.coordinate.coordinate2D) {
                    Button {
                        presentCreationView(for: selectedSearchResult)
                    } label: {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(Color(red: 0.18, green: 0.15, blue: 0.12), .white)
                    }
                    .buttonStyle(.plain)
                }
            }
            if locationAvailable {
                UserAnnotation()
            }
        }
        .tint(Color(red: 0.78, green: 1.00, blue: 0.24))
    }

    // MARK: - Search + Filters

    private var mapSearchAndFilters: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.secondary)

                TextField("Search map...", text: $searchQuery)
                    .font(.system(size: 15, weight: .semibold))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()

                Divider()
                    .frame(height: 24)

                Button {
                    centreOnUserIfPossible()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.16))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(.white.opacity(0.92), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color(red: 0.78, green: 0.73, blue: 0.64).opacity(0.28), lineWidth: 1)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    poiFilterChip(title: "All", icon: "square.grid.2x2", type: nil)

                    ForEach(MapScreenViewModel.discoverableCategories) { type in
                        poiFilterChip(title: type.displayName, icon: icon(for: type), type: type)
                    }
                }
                .padding(.horizontal, 2)
            }

            if !viewModel.searchResults.isEmpty && !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchResultsPanel
            }
        }
    }

    private var searchResultsPanel: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.searchResults) { result in
                Button {
                    selectSearchResult(result)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 18, height: 18)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(result.title)
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(Color(red: 0.18, green: 0.15, blue: 0.12))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if !result.subtitle.isEmpty {
                                Text(result.subtitle)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if result.id != viewModel.searchResults.last?.id {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 0.78, green: 0.73, blue: 0.64).opacity(0.24), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 20, x: 0, y: 10)
    }

    private func poiFilterChip(title: String, icon: String, type: PlaceType?) -> some View {
        let isSelected = viewModel.selectedPOICategory == type
        let tint = type.map(color(for:)) ?? Color(red: 0.78, green: 1.00, blue: 0.24)

        return Button {
            Task {
                await viewModel.selectCategoryAndRefresh(type)
                fitVisibleAnnotations()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .heavy))
            }
            .foregroundStyle(Color(red: 0.18, green: 0.15, blue: 0.12))
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(
                Capsule()
                    .fill(isSelected ? tint.opacity(0.85) : .white.opacity(0.88))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? tint.opacity(0.95) : tint.opacity(0.20), lineWidth: isSelected ? 1.3 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var quickAddBar: some View {
        HStack(spacing: 18) {
            barItem("list.bullet", "Reminders", tab: .reminders)
            barItem("square.stack.3d.up", "Places", tab: .places)
            barItem("map", "Map", tab: .map)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal, 14)
        .padding(.bottom, -8)
    }

    private func barItem(_ icon: String, _ title: String, tab: AppTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 24, height: 22, alignment: .center)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .frame(height: 12, alignment: .center)
            }
            .foregroundStyle(selectedTab == tab ? Color(red: 0.28, green: 0.23, blue: 0.16) : .secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 56, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    // True when the user has granted location permission, so we can show the blue user-location dot.
    private var locationAvailable: Bool {
        viewModel.authorization == .full || viewModel.authorization == .foregroundOnly
    }

    private var visibleSavedPlaces: [Place] {
        guard let selectedType = viewModel.selectedPOICategory else {
            return viewModel.places
        }
        return viewModel.places.filter { $0.placeType == selectedType }
    }

    private var visibleMapPlaces: [Place] {
        visibleSavedPlaces + viewModel.pois
    }

    // Move the map to centre on the user's current location. Does nothing if we don't have a location yet.
    private func centreOnUserIfPossible() {
        guard let coord = viewModel.currentCoordinate else { return }
        cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: coord.latitude,
                    longitude: coord.longitude
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )
    }

    private func selectSearchResult(_ result: AddressSuggestion) {
        selectedSearchResult = result
        searchQuery = result.title
        viewModel.clearSearchResults()

        withAnimation(.easeInOut(duration: 0.28)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: result.coordinate.coordinate2D,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            )
        }
    }

    private func fitVisibleAnnotations() {
        let places = visibleMapPlaces
        guard !places.isEmpty else {
            centreOnUserIfPossible()
            return
        }

        let coordinates = places.map(\.coordinate2D)
        let minLatitude = coordinates.map(\.latitude).min() ?? 0
        let maxLatitude = coordinates.map(\.latitude).max() ?? 0
        let minLongitude = coordinates.map(\.longitude).min() ?? 0
        let maxLongitude = coordinates.map(\.longitude).max() ?? 0

        let latitudeDelta = max(0.012, (maxLatitude - minLatitude) * 1.8)
        let longitudeDelta = max(0.012, (maxLongitude - minLongitude) * 1.8)

        withAnimation(.easeInOut(duration: 0.28)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: (minLatitude + maxLatitude) / 2,
                        longitude: (minLongitude + maxLongitude) / 2
                    ),
                    span: MKCoordinateSpan(
                        latitudeDelta: latitudeDelta,
                        longitudeDelta: longitudeDelta
                    )
                )
            )
        }
    }

    // A coloured circle with an icon inside it. We use this for every map pin. `dimmed` makes POI pins look different from saved Place pins.
    @ViewBuilder
    private func pinView(for type: PlaceType, dimmed: Bool) -> some View {
        Image(systemName: icon(for: type))
            .font(.caption)
            .foregroundStyle(textColor(for: type))
            .padding(6)
            .background(
                Circle()
                    .fill(color(for: type))
                    .opacity(dimmed ? 0.6 : 1.0)
            )
            .overlay(Circle().stroke(textColor(for: type).opacity(dimmed ? 0.28 : 0.55), lineWidth: 1))
    }

    private func pinButton(for suggestion: AddressSuggestion, type: PlaceType, dimmed: Bool) -> some View {
        Button {
            presentCreationView(for: suggestion)
        } label: {
            pinView(for: type, dimmed: dimmed)
        }
        .buttonStyle(.plain)
    }

    private func icon(for type: PlaceType) -> String {
        switch type {
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .supermarket: return "cart.fill"
        case .pharmacy: return "cross.case.fill"
        case .postOffice: return "envelope.fill"
        case .custom: return "mappin"
        }
    }

    private func color(for type: PlaceType) -> Color {
        switch type {
        case .home:
            return Color(red: 1.00, green: 0.76, blue: 0.65)
        case .work:
            return Color(red: 0.68, green: 0.85, blue: 1.00)
        case .supermarket:
            return Color(red: 0.84, green: 1.00, blue: 0.40)
        case .pharmacy:
            return Color(red: 0.82, green: 0.72, blue: 1.00)
        case .postOffice:
            return Color(red: 1.00, green: 0.84, blue: 0.48)
        case .custom:
            return Color(red: 0.93, green: 0.88, blue: 1.00)
        }
    }

    private func textColor(for type: PlaceType) -> Color {
        switch type {
        case .home:
            return Color(red: 0.40, green: 0.16, blue: 0.08)
        case .work:
            return Color(red: 0.05, green: 0.22, blue: 0.38)
        case .supermarket:
            return Color(red: 0.18, green: 0.27, blue: 0.08)
        case .pharmacy:
            return Color(red: 0.22, green: 0.10, blue: 0.48)
        case .postOffice:
            return Color(red: 0.42, green: 0.24, blue: 0.04)
        case .custom:
            return Color(red: 0.30, green: 0.18, blue: 0.42)
        }
    }

    private func suggestion(from place: Place) -> AddressSuggestion {
        AddressSuggestion(
            title: place.name,
            subtitle: place.placeType.displayName,
            coordinate: LocationCoordinate(latitude: place.latitude, longitude: place.longitude)
        )
    }

    private func presentCreationView(for suggestion: AddressSuggestion) {
        creationViewModel = viewModel.makeCreationViewModel(from: suggestion)
    }
}

// MARK: - Place → coordinate

// Apple's Map view wants its coordinates in a specific Apple type. Place stores them as plain numbers; this little helper converts.
private extension Place {
    var coordinate2D: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension LocationCoordinate {
    var coordinate2D: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Previews

struct MapScreenView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MapScreenView(viewModel: populatedViewModel, selectedTab: .constant(.map))
                .previewDisplayName("With Places + POIs")

            MapScreenView(
                viewModel: MapScreenViewModel(
                    store: InMemoryPlaceStore(),
                    location: ScriptedLocationProvider(authorization: .denied, currentCoordinate: nil),
                    searcher: StaticAddressSearcher(),
                    geocoder: StaticGeocoder(),
                    poiDiscovery: StaticPOIDiscovery()
                ),
                selectedTab: .constant(.map)
            )
            .previewDisplayName("Empty + denied permission")
        }
    }

    private static var populatedViewModel: MapScreenViewModel {
        let store = InMemoryPlaceStore(places: [
            Place(name: "Home", placeType: .home, latitude: -33.8688, longitude: 151.2093),
            Place(name: "Uni", placeType: .work, latitude: -33.8915, longitude: 151.1955)
        ])
        let location = ScriptedLocationProvider(
            authorization: .full,
            currentCoordinate: LocationCoordinate(latitude: -33.8800, longitude: 151.2050)
        )
        let viewModel = MapScreenViewModel(
            store: store,
            location: location,
            searcher: StaticAddressSearcher(),
            geocoder: StaticGeocoder(),
            poiDiscovery: StaticPOIDiscovery()
        )
        viewModel.selectedPOICategory = .supermarket
        Task { await viewModel.refreshPOIs() }
        return viewModel
    }
}
