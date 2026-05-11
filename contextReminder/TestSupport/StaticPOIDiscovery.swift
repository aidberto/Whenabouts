
import Foundation

// In-memory `POIDiscovering`. Returns fixtures keyed by `PlaceType`. Default fixtures cover supermarket / pharmacy / postOffice (Sydney area).
final class StaticPOIDiscovery: POIDiscovering {
    var fixtures: [PlaceType: [Place]]

    init(fixtures: [PlaceType: [Place]] = StaticPOIDiscovery.defaults) {
        self.fixtures = fixtures
    }

    // Returns up to `limit` fixtures for the requested category. Ignores the `near` coordinate — fixtures are static.
    func nearestPOIs(
        category: PlaceType,
        near: LocationCoordinate,
        limit: Int
    ) async -> [Place] {
        let all = fixtures[category] ?? []
        return Array(all.prefix(limit))
    }

    // Default fixtures — Sydney CBD area, mirroring real-world venues.
    static let defaults: [PlaceType: [Place]] = [
        .supermarket: [
            Place(name: "Coles Broadway", placeType: .supermarket, latitude: -33.8836, longitude: 151.1959),
            Place(name: "Woolworths Town Hall", placeType: .supermarket, latitude: -33.8736, longitude: 151.2070),
            Place(name: "IGA Pyrmont", placeType: .supermarket, latitude: -33.8700, longitude: 151.1955)
        ],
        .pharmacy: [
            Place(name: "Chemist Warehouse Broadway", placeType: .pharmacy, latitude: -33.8800, longitude: 151.2000),
            Place(name: "Priceline Town Hall", placeType: .pharmacy, latitude: -33.8730, longitude: 151.2065)
        ],
        .postOffice: [
            Place(name: "Australia Post Glebe", placeType: .postOffice, latitude: -33.8790, longitude: 151.1860),
            Place(name: "Australia Post Sydney CBD", placeType: .postOffice, latitude: -33.8688, longitude: 151.2093)
        ]
    ]
}
