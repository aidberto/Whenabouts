//
//  ReminderTarget.swift
//  contextReminder
//
//  Created by Brian Jones Porianto on 05/02/26
//

import Foundation

//To diferentiate between user choosen place or "any place"
//ex: "Any supermarket", "Any pharmacy", etc.
enum ReminderTarget: Codable, Equatable {
    //for choosen place
    case place(Place)
    //for any place
    case placeType(PlaceType)
}
