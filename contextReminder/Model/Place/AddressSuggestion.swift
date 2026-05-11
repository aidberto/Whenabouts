//
//  AddressSuggestion.swift
//  contextReminder
//
//  Created by Brian Jones Porianto on 3/5/2026.
//

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
