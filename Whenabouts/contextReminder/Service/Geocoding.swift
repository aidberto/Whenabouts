//
//  Geocoding.swift
//  contextReminder
//
//  Describes "the thing that turns a coordinate into a human-readable address."
//  Used by the map-pin Place picker so the user can confirm the spot they
//  pinned matches what they expect.
//
//  The real app uses CLGeocoder_Geocoder, which calls Apple's MapKit reverse
//  geocoder. The class name is kept so the rest of the app does not need to
//  change.
//  Tests and previews use StaticGeocoder, which returns a fixed string.
//

import Foundation
import MapKit

protocol Geocoding {
    /// Look up the address at this coordinate. Returns nil if not found
    /// or something goes wrong.
    func address(for coordinate: LocationCoordinate) async -> String?
}

/// Real-app version. Uses Apple's MapKit reverse geocoder.
final class CLGeocoder_Geocoder: Geocoding {
    func address(for coordinate: LocationCoordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return nil
        }

        do {
            let mapItems = try await request.mapItems
            guard let first = mapItems.first else { return nil }

            if let address = first.addressRepresentations?.fullAddress(
                includingRegion: false,
                singleLine: true
            ) {
                return address
            }

            return first.address?.shortAddress ?? first.address?.fullAddress
        } catch {
            return nil
        }
    }
}
