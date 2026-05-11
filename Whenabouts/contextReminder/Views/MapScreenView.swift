//
//  MapScreenView.swift
//  contextReminder
//
//  Map screen. Shows the user's saved Places as coloured pins.
//  A search bar at the top lets the user fly to any address. The POI
//  category picker lives inside that bar as a trailing button.
//
//  Map features added:
//  • Re-centre button — snaps the camera back to the user's location.
//    Appears with a pulse animation whenever the user pans away.
//  • Map style toggle — cycles between Standard and Satellite imagery.
//

import SwiftUI
import MapKit

struct MapScreenView: View {
    @StateObject var viewModel: MapScreenViewModel
    @Binding var selectedTab: AppTab

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var isShowingPOIFilters = false
    @FocusState private var searchFocused: Bool

    // ── New map feature state ────────────────────────────────────────────────
    /// True when the camera has moved away from the user's location, so the
    /// re-centre button should be visible.
    @State private var isOffCentre = false
    /// Tracks how many times the position changed so we can detect user pans.
    @State private var cameraPositionChangeCount = 0
    /// Whether we are currently performing a programmatic camera move (so we
    /// don't incorrectly flag it as a user pan).
    @State private var isProgrammaticMove = false
    /// Satellite vs. standard.
    @State private var isSatellite = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // ── Map fills the whole screen ──────────────────────────────
                mapContent
                    .mapStyle(
                        isSatellite
                            ? .imagery(elevation: .flat)
                            : .standard(
                                elevation: .flat,
                                emphasis: .muted,
                                pointsOfInterest: .excludingAll,
                                showsTraffic: false
                            )
                    )
                    .ignoresSafeArea()
                    // Detect when the camera position object itself changes
                    // (covers both user drags and programmatic moves).
                    .onMapCameraChange { _ in
                        guard !isProgrammaticMove else { return }
                        isOffCentre = true
                    }

                // ── Search bar overlay at top ────────────────────────────────
                VStack(spacing: 0) {
                    searchBar
                        .padding(.horizontal, 14)
                        .padding(.top, 56)

                    // POI filter chips — slide in below the bar when open
                    if isShowingPOIFilters {
                        poiFilterPanel
                            .padding(.horizontal, 14)
                            .padding(.top, 6)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // Address suggestions list
                    if !viewModel.mapSearchResults.isEmpty {
                        suggestionsPanel
                            .padding(.horizontal, 14)
                            .padding(.top, 6)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Spacer()
                }

                // ── Floating control buttons (bottom-right) ──────────────────
                VStack(spacing: 10) {
                    Spacer()

                    // Map style toggle
                    mapStyleButton

                    // Re-centre button — only visible when off-centre
                    if isOffCentre {
                        reCentreButton
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.trailing, 14)
                .padding(.bottom, 88) // clear the tab bar
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { quickAddBar }
            .toolbar(.hidden, for: .tabBar)
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
            .onChange(of: viewModel.mapSearchQuery) { _, _ in
                viewModel.scheduleMapSearch()
            }
            .onChange(of: viewModel.mapSearchSelection) { _, newCoord in
                guard let coord = newCoord else { return }
                flyTo(coord)
            }
        }
    }

    // MARK: - Re-centre button

    private var reCentreButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                centreOnUserIfPossible()
                isOffCentre = false
            }
        } label: {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Color(red: 0.78, green: 0.73, blue: 0.64).opacity(0.3), lineWidth: 1))
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)

                Image(systemName: "location.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 0.78, green: 1.00, blue: 0.24))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Re-centre on my location")
    }

    // MARK: - Map style toggle

    private var mapStyleButton: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                isSatellite.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Color(red: 0.78, green: 0.73, blue: 0.64).opacity(0.3), lineWidth: 1))
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)

                Image(systemName: isSatellite ? "map.fill" : "globe.americas.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 0.28, green: 0.23, blue: 0.16))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSatellite ? "Switch to standard map" : "Switch to satellite view")
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("Search map…", text: $viewModel.mapSearchQuery)
                .font(.system(size: 15, weight: .semibold))
                .focused($searchFocused)
                .onSubmit {
                    if let first = viewModel.mapSearchResults.first {
                        viewModel.selectMapSearchResult(first)
                        flyTo(first.coordinate)
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            searchFocused = false
                            isShowingPOIFilters = false
                        }
                    }
                }

            // Clear button — only while there's text
            if !viewModel.mapSearchQuery.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                        viewModel.clearMapSearch()
                        searchFocused = false
                        isShowingPOIFilters = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }

            Divider()
                .frame(height: 22)
                .padding(.horizontal, 2)

            // POI category picker button — integrated into the right of the bar
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    isShowingPOIFilters.toggle()
                    searchFocused = false
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 14, weight: .semibold))
                    if let category = viewModel.selectedPOICategory {
                        Text(category.displayName)
                            .font(.system(size: 12, weight: .bold))
                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    }
                }
                .foregroundStyle(
                    viewModel.selectedPOICategory != nil
                        ? Color(red: 0.08, green: 0.28, blue: 0.08)
                        : Color(red: 0.18, green: 0.15, blue: 0.12)
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        viewModel.selectedPOICategory != nil
                            ? Color(red: 0.78, green: 1.00, blue: 0.24).opacity(0.72)
                            : Color.clear
                    )
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(viewModel.selectedPOICategory?.displayName ?? "Nearby places filter")
            .animation(.spring(response: 0.22, dampingFraction: 0.8), value: viewModel.selectedPOICategory)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(red: 0.78, green: 0.73, blue: 0.64).opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
    }

    // MARK: - POI filter chips

    private var poiFilterPanel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                poiChip(title: "All", icon: "square.grid.2x2", type: nil)
                ForEach(MapScreenViewModel.discoverableCategories) { type in
                    poiChip(title: type.displayName, icon: icon(for: type), type: type)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.78, green: 0.73, blue: 0.64).opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
    }

    private func poiChip(title: String, icon: String, type: PlaceType?) -> some View {
        let isSelected = viewModel.selectedPOICategory == type
        return Button {
            Task {
                await viewModel.selectCategoryAndRefresh(type)
                fitVisibleAnnotations()
                withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                    isShowingPOIFilters = false
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(isSelected ? Color(red: 0.08, green: 0.28, blue: 0.08) : Color(red: 0.18, green: 0.15, blue: 0.12))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(
                    isSelected
                        ? Color(red: 0.78, green: 1.00, blue: 0.24).opacity(0.72)
                        : Color(red: 0.98, green: 0.95, blue: 0.90).opacity(0.0)
                )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Address suggestions

    private var suggestionsPanel: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.mapSearchResults.enumerated()), id: \.element.id) { index, suggestion in
                Button {
                    viewModel.selectMapSearchResult(suggestion)
                    flyTo(suggestion.coordinate)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        searchFocused = false
                        isShowingPOIFilters = false
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color(red: 0.78, green: 1.00, blue: 0.24))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color(red: 0.18, green: 0.15, blue: 0.12))
                                .lineLimit(1)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                }
                .buttonStyle(.plain)

                if index < viewModel.mapSearchResults.count - 1 {
                    Divider()
                        .padding(.leading, 46)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 0.78, green: 0.73, blue: 0.64).opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
    }

    // MARK: - Map content

    private var mapContent: some View {
        Map(position: $cameraPosition) {
            ForEach(visibleSavedPlaces) { place in
                Annotation(place.name, coordinate: place.coordinate2D) {
                    pinView(for: place.placeType, dimmed: false)
                }
            }
            ForEach(viewModel.pois) { poi in
                Annotation(poi.name, coordinate: poi.coordinate2D) {
                    pinView(for: poi.placeType, dimmed: true)
                }
            }
            if locationAvailable {
                UserAnnotation()
            }
        }
        .tint(Color(red: 0.78, green: 1.00, blue: 0.24))
        .onTapGesture {
            // Dismiss search and filters when tapping the map
            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                searchFocused = false
                isShowingPOIFilters = false
            }
        }
    }

    // MARK: - Bottom tab bar

    private var quickAddBar: some View {
        HStack(spacing: 18) {
            barItem("list.bullet", "Reminders", tab: .reminders)
            barItem("square.stack.3d.up.fill", "Places", tab: .places)
            barItem("map", "Map", tab: .map)
            #if DEBUG
            barItem("ladybug", "Debug", tab: .debug)
            #endif
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

    private var locationAvailable: Bool {
        viewModel.authorization == .full || viewModel.authorization == .foregroundOnly
    }

    private var visibleSavedPlaces: [Place] {
        guard let selectedType = viewModel.selectedPOICategory else { return viewModel.places }
        return viewModel.places.filter { $0.placeType == selectedType }
    }

    private var visibleMapPlaces: [Place] {
        visibleSavedPlaces + viewModel.pois
    }

    /// Move the camera to the user's current location (programmatic — does NOT
    /// set `isOffCentre`).
    private func centreOnUserIfPossible() {
        guard let coord = viewModel.currentCoordinate else { return }
        isProgrammaticMove = true
        cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
        )
        // Give MapKit a moment to consume the change before we re-enable pan detection.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            isProgrammaticMove = false
        }
    }

    private func flyTo(_ coord: LocationCoordinate) {
        isProgrammaticMove = true
        withAnimation(.easeInOut(duration: 0.6)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
                )
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isProgrammaticMove = false
            isOffCentre = true  // searched location ≠ user location, so show re-centre
        }
    }

    private func fitVisibleAnnotations() {
        let places = visibleMapPlaces
        guard !places.isEmpty else { centreOnUserIfPossible(); return }

        let coordinates = places.map(\.coordinate2D)
        let minLat = coordinates.map(\.latitude).min() ?? 0
        let maxLat = coordinates.map(\.latitude).max() ?? 0
        let minLng = coordinates.map(\.longitude).min() ?? 0
        let maxLng = coordinates.map(\.longitude).max() ?? 0

        isProgrammaticMove = true
        withAnimation(.easeInOut(duration: 0.28)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: (minLat + maxLat) / 2,
                        longitude: (minLng + maxLng) / 2
                    ),
                    span: MKCoordinateSpan(
                        latitudeDelta: max(0.012, (maxLat - minLat) * 1.8),
                        longitudeDelta: max(0.012, (maxLng - minLng) * 1.8)
                    )
                )
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isProgrammaticMove = false
        }
    }

    // MARK: - Pin views

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
        case .home:        return Color(red: 1.00, green: 0.76, blue: 0.65)
        case .work:        return Color(red: 0.68, green: 0.85, blue: 1.00)
        case .supermarket: return Color(red: 0.84, green: 1.00, blue: 0.40)
        case .pharmacy:    return Color(red: 0.82, green: 0.72, blue: 1.00)
        case .postOffice:  return Color(red: 1.00, green: 0.84, blue: 0.48)
        case .custom:      return Color(red: 0.93, green: 0.88, blue: 1.00)
        }
    }

    private func textColor(for type: PlaceType) -> Color {
        switch type {
        case .home:        return Color(red: 0.40, green: 0.16, blue: 0.08)
        case .work:        return Color(red: 0.05, green: 0.22, blue: 0.38)
        case .supermarket: return Color(red: 0.18, green: 0.27, blue: 0.08)
        case .pharmacy:    return Color(red: 0.22, green: 0.10, blue: 0.48)
        case .postOffice:  return Color(red: 0.42, green: 0.24, blue: 0.04)
        case .custom:      return Color(red: 0.30, green: 0.18, blue: 0.42)
        }
    }
}

// MARK: - Place → coordinate

private extension Place {
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
            poiDiscovery: StaticPOIDiscovery()
        )
        viewModel.selectedPOICategory = .supermarket
        Task { await viewModel.refreshPOIs() }
        return viewModel
    }
}
