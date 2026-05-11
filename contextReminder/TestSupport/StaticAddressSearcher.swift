//
//  StaticAddressSearcher.swift
//  contextReminder
//
//  Created by Brian Jones Porianto on 3/5/2026.
//

import Foundation

final class StaticAddressSearcher: AddressSearching {
    var results: [AddressSuggestion]

    init(results: [AddressSuggestion] = StaticAddressSearcher.defaults) {
        self.results = results
    }

    func search(query: String) async -> [AddressSuggestion] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return results
    }

    static let defaults: [AddressSuggestion] = [
        AddressSuggestion(
            title: "Coles Broadway",
            subtitle: "Bay Street, Broadway NSW",
            coordinate: LocationCoordinate(latitude: -33.8836, longitude: 151.1959)
        ),
        AddressSuggestion(
            title: "Chemist Warehouse Broadway",
            subtitle: "Greek Street, Glebe NSW",
            coordinate: LocationCoordinate(latitude: -33.8800, longitude: 151.2000)
        ),
        AddressSuggestion(
            title: "Australia Post Glebe",
            subtitle: "Glebe Point Road, Glebe NSW",
            coordinate: LocationCoordinate(latitude: -33.8790, longitude: 151.1860)
        )
    ]
}
