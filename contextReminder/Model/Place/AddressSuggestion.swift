
import Foundation

struct AddressSuggestion: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
    let coordinate: LocationCoordinate

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        coordinate: LocationCoordinate
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
    }
}
