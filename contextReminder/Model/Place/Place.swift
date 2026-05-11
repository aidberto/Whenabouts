//
//  Place.swift
//  contextReminder
//
//  Created by Brian Jones Porianto on 05/02/26
//

import Foundation
//to identify the selected place 
struct Place: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var placeType: PlaceType
    var latitude: Double
    var longitude: Double
    var radius: Double

    init(
        id: UUID = UUID(),
        name: String,
        placeType: PlaceType,
        latitude: Double,
        longitude: Double,
        radius: Double = 5000
    ) {
        self.id = id
        self.name = name
        self.placeType = placeType
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
    }
}
