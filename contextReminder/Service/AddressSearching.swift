//
//  AddressSearching.swift
//  contextReminder
//
//  Describes "the thing that turns a typed address into a list of suggestions."
//
//  The real app uses MKLocalAddressSearcher, which calls Apple's map search.
//  Tests and previews use StaticAddressSearcher, which returns canned results.
//

import Foundation
import MapKit

protocol AddressSearching {
    /// Look up places matching `query`. Returns up to ~10 suggestions.
    /// Returns an empty list if the query is empty or something goes wrong.
    func search(query: String) async -> [AddressSuggestion]
}

/// Real-app version. Uses Apple's MKLocalSearch to look things up.
final class MKLocalAddressSearcher: AddressSearching {

    /// Optional region used to bias results toward the user's current location.
    /// When set, Apple's search engine heavily prefers results near this area,
    /// which is what makes "Coles" return Australian supermarkets instead of
    /// something on the other side of the world.
    var regionBias: MKCoordinateRegion?

    func search(query: String) async -> [AddressSuggestion] {
        // Strip whitespace and bail if the query is just spaces.
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // Build the search request — accepts addresses and points of interest.
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.address, .pointOfInterest]

        // Bias results toward the user's current area if we have a location.
        // A 50 km span gives good local coverage while still finding chain
        // stores with a single named location (e.g. "Coles" in Sydney).
        if let region = regionBias {
            request.region = region
        }

        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            // Convert each result into our own AddressSuggestion type.
            // Cap at 10 so the user isn't overwhelmed by suggestions.
            return response.mapItems.prefix(10).map { item in
                AddressSuggestion(
                    title: item.name ?? trimmed,
                    subtitle: item.placemark.formattedAddress,
                    coordinate: LocationCoordinate(
                        latitude: item.placemark.coordinate.latitude,
                        longitude: item.placemark.coordinate.longitude
                    )
                )
            }
        } catch {
            // Network failure or no results — return empty rather than crashing.
            print("AddressSearcher error: \(error)")
            return []
        }
    }
}

private extension MKPlacemark {
    /// Human-readable address from the placemark's components.
    var formattedAddress: String {
        [subThoroughfare, thoroughfare, locality, administrativeArea]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}
