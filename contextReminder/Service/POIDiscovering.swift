
import Foundation
import MapKit

protocol POIDiscovering {
    // Find nearby category places within 5km, excluding personal saved-place types.
    func nearestPOIs(
        category: PlaceType,
        near: LocationCoordinate,
        limit: Int
    ) async -> [Place]
}

// Real-app version. Uses Apple's MKLocalPointsOfInterestRequest.
final class MKLocalPOIDiscovery: POIDiscovering {

    // Convert app place types to Apple POI categories where possible.
    private func appleCategory(for type: PlaceType) -> MKPointOfInterestCategory? {
        switch type {
        case .supermarket: return .foodMarket
        case .pharmacy: return .pharmacy
        case .postOffice: return .postOffice
        case .home, .work, .custom: return nil
        }
    }

    func nearestPOIs(
        category: PlaceType,
        near: LocationCoordinate,
        limit: Int
    ) async -> [Place] {
        // Personal categories — return empty, no Apple equivalent.
        guard let appleCat = appleCategory(for: category) else { return [] }

        // Build a 5km box around the user's coordinate.
        let centre = CLLocationCoordinate2D(
            latitude: near.latitude,
            longitude: near.longitude
        )
        let region = MKCoordinateRegion(
            center: centre,
            latitudinalMeters: 5_000,
            longitudinalMeters: 5_000
        )
        let filter = MKPointOfInterestFilter(including: [appleCat])
        let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
        request.pointOfInterestFilter = filter

        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            // Convert each map item into a Place.
            return response.mapItems.prefix(limit).map { item in
                Place(
                    name: item.name ?? category.displayName,
                    placeType: category,
                    latitude: item.location.coordinate.latitude,
                    longitude: item.location.coordinate.longitude
                )
            }
        } catch {
            print("POIDiscovery error: \(error)")
            return []
        }
    }
}
