//
//  LocationCoordinate.swift
//  contextReminder
//
//  Created by Brian Jones Porianto on 3/5/2026.
//

import Foundation

//translate CLLocation(Apple corelocation type to this) safety measure
struct LocationCoordinate: Equatable {
    let latitude: Double
    let longitude: Double
}
