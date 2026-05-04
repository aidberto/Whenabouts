//
//  MapScreenView.swift
//  contextReminder
//
//  Map screen. Shows the user's saved Places as coloured pins.
//  Optional category picker (top-right) shows nearby POIs of one type
//  (supermarket, pharmacy, post office). Blue user-location dot appears
//  when permission is granted.
//

import SwiftUI
import MapKit

struct MapScreenView: View {
    @StateObject var viewModel: MapScreenViewModel

    /// Where the map is currently looking. We move it to the user's location
    /// once we have one, otherwise it auto-fits to the pins.
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            mapContent
                .mapControls {
                    if locationAvailable {
                        MapUserLocationButton()
                    }
                    MapCompass()
                }
                .navigationTitle("Map")
                .toolbar { toolbarContent }
                .onAppear { centreOnUserIfPossible() }
                .onChange(of: viewModel.currentCoordinate?.latitude) { _, _ in
                    centreOnUserIfPossible()
                }
        }
    }

    // MARK: - Map content

    /// The Map itself. Three layers: saved Places, discovered POIs, user dot.
    private var mapContent: some View {
        Map(position: $cameraPosition) {
            ForEach(viewModel.places) { place in
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
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("None") { viewModel.selectCategory(nil) }
                ForEach(MapScreenViewModel.discoverableCategories) { type in
                    Button(type.displayName) { viewModel.selectCategory(type) }
                }
            } label: {
                Label(
                    viewModel.selectedPOICategory?.displayName ?? "POIs",
                    systemImage: "magnifyingglass"
                )
            }
        }
    }

    // MARK: - Helpers

    /// True when the user has granted location permission, so we can show
    /// the blue user-location dot.
    private var locationAvailable: Bool {
        viewModel.authorization == .full || viewModel.authorization == .foregroundOnly
    }

    /// Move the map to centre on the user's current location.
    /// Does nothing if we don't have a location yet.
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

    /// A coloured circle with an icon inside it. We use this for every map pin.
    /// `dimmed` makes POI pins look different from saved Place pins.
    @ViewBuilder
    private func pinView(for type: PlaceType, dimmed: Bool) -> some View {
        Image(systemName: icon(for: type))
            .font(.caption)
            .foregroundStyle(.white)
            .padding(6)
            .background(
                Circle()
                    .fill(color(for: type))
                    .opacity(dimmed ? 0.6 : 1.0)
            )
            .shadow(radius: 2)
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
        case .home: return .blue
        case .work: return .orange
        case .supermarket: return .green
        case .pharmacy: return .red
        case .postOffice: return .purple
        case .custom: return .gray
        }
    }
}

// MARK: - Place → coordinate

/// Apple's Map view wants its coordinates in a specific Apple type.
/// Place stores them as plain numbers; this little helper converts.
private extension Place {
    var coordinate2D: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Previews

#Preview("With Places + POIs") {
    let store = InMemoryPlaceStore(places: [
        Place(name: "Home", placeType: .home, latitude: -33.8688, longitude: 151.2093),
        Place(name: "Uni", placeType: .work, latitude: -33.8915, longitude: 151.1955)
    ])
    let location = ScriptedLocationProvider(
        authorization: .full,
        currentCoordinate: LocationCoordinate(latitude: -33.8800, longitude: 151.2050)
    )
    let poi = StaticPOIDiscovery()
    let vm = MapScreenViewModel(store: store, location: location, poiDiscovery: poi)
    vm.selectedPOICategory = .supermarket
    Task { await vm.refreshPOIs() }
    return MapScreenView(viewModel: vm)
}

#Preview("Empty + denied permission") {
    MapScreenView(
        viewModel: MapScreenViewModel(
            store: InMemoryPlaceStore(),
            location: ScriptedLocationProvider(authorization: .denied, currentCoordinate: nil),
            poiDiscovery: StaticPOIDiscovery()
        )
    )
}
