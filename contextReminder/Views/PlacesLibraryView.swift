//
//  PlacesLibraryView.swift
//  contextReminder
//
//  Lists all the user's saved Places. Tap + to add a new one,
//  tap a row to edit, or swipe to delete.
//

import SwiftUI

struct PlacesLibraryView: View {
    @StateObject var viewModel: PlacesLibraryViewModel

    /// When non-nil, the create/edit sheet is shown. Setting this back to nil
    /// dismisses the sheet.
    @State private var creationViewModel: PlaceCreationViewModel?

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.places) { place in
                    Button {
                        // Tap a row → open the edit sheet for this Place.
                        creationViewModel = viewModel.makeCreationViewModel(editing: place)
                    } label: {
                        placeRow(place)
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: viewModel.delete)
            }
            .navigationTitle("Places")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    // Plus button → open the create sheet.
                    Button {
                        creationViewModel = viewModel.makeCreationViewModel()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay {
                if viewModel.places.isEmpty {
                    ContentUnavailableView(
                        "No places yet",
                        systemImage: "mappin.slash",
                        description: Text("Tap + to save your first place.")
                    )
                }
            }
            .sheet(item: $creationViewModel) { vm in
                PlaceCreationView(viewModel: vm)
            }
        }
    }

    /// One row in the list — name in big text, type in small grey text underneath.
    private func placeRow(_ place: Place) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.name).font(.headline)
            Text(place.placeType.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// Lets us drive the create/edit sheet using `.sheet(item:)`.
/// Each PlaceCreationViewModel is uniquely identified by its memory address.
extension PlaceCreationViewModel: Identifiable {
    public var id: ObjectIdentifier { ObjectIdentifier(self) }
}

struct PlacesLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PlacesLibraryView(
                viewModel: PlacesLibraryViewModel(
                    store: InMemoryPlaceStore(places: [
                        Place(name: "Home", placeType: .home, latitude: -33.8688, longitude: 151.2093),
                        Place(name: "Coles Broadway", placeType: .supermarket, latitude: -33.8836, longitude: 151.1959)
                    ]),
                    location: ScriptedLocationProvider(),
                    searcher: StaticAddressSearcher(),
                    geocoder: StaticGeocoder()
                )
            )
            .previewDisplayName("With places")

            PlacesLibraryView(
                viewModel: PlacesLibraryViewModel(
                    store: InMemoryPlaceStore(),
                    location: ScriptedLocationProvider(),
                    searcher: StaticAddressSearcher(),
                    geocoder: StaticGeocoder()
                )
            )
            .previewDisplayName("Empty")
        }
    }
}
