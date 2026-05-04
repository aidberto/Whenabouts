//
//  Geocoding.swift
//  contextReminder
//
//  Describes "the thing that turns a coordinate into a human-readable address."
//  Used by the map-pin Place picker so the user can confirm the spot they
//  pinned matches what they expect.
//
//  The real app uses CLGeocoder_Geocoder, which calls Apple's geocoder.
//  Tests and previews use StaticGeocoder, which returns a fixed string.
//

import Foundation
import CoreLocation

protocol Geocoding {
    /// Look up the address at this coordinate. Returns nil if not found
    /// or something goes wrong.
    func address(for coordinate: LocationCoordinate) async -> String?
}

/// Real-app version. Uses Apple's CLGeocoder for reverse geocoding.
final class CLGeocoder_Geocoder: Geocoding {
    private let geocoder = CLGeocoder()

    func address(for coordinate: LocationCoordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let first = placemarks.first else { return nil }
            // Build a short address like "42 Smith Street Sydney" by joining
            // the parts that are available.
            return [first.subThoroughfare, first.thoroughfare, first.locality]
                .compactMap { $0 }
                .joined(separator: " ")
        } catch {
            return nil
        }
    }
}
