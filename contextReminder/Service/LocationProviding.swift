
import Foundation
import Combine

protocol LocationProviding: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    // Current permission state — has the user said yes, no, or not yet?
    var authorization: LocationAuthorization { get }

    // Latest known coordinate. Nil until permission is granted and the GPS gets a fix.
    var currentCoordinate: LocationCoordinate? { get }

    // Show the iOS "Allow While Using App" prompt. iOS only shows it once; after that this method does nothing.
    func requestWhenInUseAuthorization()

    // Open the iOS Settings app to this app's row. Used when the user previously said no and wants to change their mind.
    func openSettings()
}
