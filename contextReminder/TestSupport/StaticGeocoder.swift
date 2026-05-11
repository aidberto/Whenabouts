
import Foundation

final class StaticGeocoder: Geocoding {
    var address: String?

    init(address: String? = "Pinned location") {
        self.address = address
    }

    func address(for coordinate: LocationCoordinate) async -> String? {
        address
    }
}
