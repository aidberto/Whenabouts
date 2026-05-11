
import Foundation
import Combine

final class InMemoryPlaceStore: PlaceStore {
    @Published private(set) var places: [Place]

    init(places: [Place] = []) {
        self.places = places
    }

    func add(_ place: Place) {
        places.append(place)
    }

    func update(_ place: Place) {
        guard let index = places.firstIndex(where: { $0.id == place.id }) else {
            return
        }
        places[index] = place
    }

    func delete(id: UUID) {
        places.removeAll { $0.id == id }
    }
}
