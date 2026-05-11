//
//  RegionTransition.swift
//  contextReminder
//
//  The two things that can happen at a geofence circle:
//  the user enters it, or the user leaves it.
//

import Foundation

enum RegionTransition: Equatable {
    case enter
    case exit
}
