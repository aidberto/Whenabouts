
import Foundation
import Combine

@MainActor
final class PlacesLibraryViewModel: ObservableObject {
    private let store: any PlaceStore
    private let location: any LocationProviding
    private let searcher: any AddressSearching
    private let geocoder: any Geocoding
    private var cancellable: AnyCancellable?

    // All saved Places, read straight from the store.
    var places: [Place] { store.places }

    init(
        store: any PlaceStore,
        location: any LocationProviding,
        searcher: any AddressSearching,
        geocoder: any Geocoding
    ) {
        self.store = store
        self.location = location
        self.searcher = searcher
        self.geocoder = geocoder
        // When the store changes, tell SwiftUI to redraw our view.
        cancellable = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // Called by SwiftUI's swipe-to-delete. `offsets` is the row indexes to remove.
    func delete(at offsets: IndexSet) {
        for index in offsets {
            store.delete(id: places[index].id)
        }
    }

    // Build a view model for the create/edit sheet. Pass an existing Place to edit it; pass nil to create a new one.
    func makeCreationViewModel(editing: Place? = nil) -> PlaceCreationViewModel {
        PlaceCreationViewModel(
            store: store,
            location: location,
            searcher: searcher,
            geocoder: geocoder,
            editing: editing
        )
    }
}
