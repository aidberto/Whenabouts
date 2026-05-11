
import Foundation
import Combine

final class ScriptedLocationProvider: LocationProviding {
    @Published private(set) var authorization: LocationAuthorization
    @Published private(set) var currentCoordinate: LocationCoordinate?

    init(
        authorization: LocationAuthorization = .full,
        currentCoordinate: LocationCoordinate? = LocationCoordinate(latitude: -33.8688, longitude: 151.2093)
    ) {
        self.authorization = authorization
        self.currentCoordinate = currentCoordinate
    }

    func requestWhenInUseAuthorization() {
        if authorization == .notDetermined {
            authorization = .foregroundOnly
        }
    }

    func openSettings() {
        // No-op in tests/previews.
    }

    func setAuthorization(_ value: LocationAuthorization) {
        authorization = value
    }

    func setCoordinate(_ value: LocationCoordinate?) {
        currentCoordinate = value
    }
}
