
import Foundation
import Combine

// What every place store must provide. Inherits from `ObservableObject` so SwiftUI views can watch it for changes.
protocol PlaceStore: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    // All saved Places. Read-only — to change the list, use the methods below.
    var places: [Place] { get }

    // Add a new Place to the list.
    func add(_ place: Place)

    // Replace the existing Place with the same id. Does nothing if not found.
    func update(_ place: Place)

    // Remove the Place with this id. Does nothing if not found.
    func delete(id: UUID)
}
