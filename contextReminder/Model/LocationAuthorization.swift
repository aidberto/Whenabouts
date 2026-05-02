//
//  LocationAuthorization.swift
//  contextReminder
//
//  Created by Brian Jones Porianto on 05/02/26
//

import Foundation
// for authorization for foreground running (if user close the app, it still run).
// User can choose between full foreground running or no.
enum LocationAuthorization: Equatable {
    case notDetermined
    case foregroundOnly
    case full
    case denied
    case restricted
    
    //default value for foreground running
    var canMonitorInBackground: Bool {
        self == .full
    }

    var canRequestUpgrade: Bool {
        switch self {
        case .notDetermined, .foregroundOnly:
            return true
        case .full, .denied, .restricted:
            return false
        }
    }
}
