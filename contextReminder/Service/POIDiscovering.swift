//
//  POIDiscovering.swift
//  contextReminder
//
//  Describes "the thing that finds nearby places of a category."
//  Used to expand a "any supermarket" reminder into specific supermarket
//  locations the user might pass.
//
//  The real app uses MKLocalPOIDiscovery, which calls Apple's catalogue.
//  Tests and previews use StaticPOIDiscovery with hardcoded fixtures.
//

import Foundation
import MapKit

protocol POIDiscovering {
    /// Find nearby places of `category` within ~5km of `near`.
    /// Returns up to `limit` results. Returns empty for personal categories
    /// (home/work/custom) — those n eed a saved Place, not a generic search.
    func nearestPOIs(
        category: PlaceType,
        near: LocationCoordinate,
        limit: Int
    ) async -> [Place]
}

/// Real-app version. Uses Apple's MKLocalPointsOfInterestRequest.
final class MKLocalPOIDiscovery: POIDiscovering {

    /// Convert our PlaceType to Apple's category.
    /// Returns nil for personal categories (home, work, custom) — Apple has
    /// no way to know about those, they have to be saved by the user manually.
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
