
import Foundation
import Combine
import CoreLocation
import UIKit

final class CoreLocationProvider: NSObject, LocationProviding {
    // Current permission state. Updates whenever the user changes it in Settings or accepts/denies the permission prompt.
    @Published private(set) var authorization: LocationAuthorization = .notDetermined

    // Latest known coordinate. Nil until permission is granted and a GPS fix arrives.
    @Published private(set) var currentCoordinate: LocationCoordinate?

    // IDs of geofence circles currently registered with iOS.
    private(set) var monitoredRegionIds: Set<UUID> = []

    // Called whenever a geofence fires (user enters or leaves a circle). `GeofenceCoordinator` sets this when the app starts up.
    var onRegionTransition: ((UUID, RegionTransition) -> Void)?

    // The actual Apple object that does the GPS work.
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        // 100m accuracy is plenty for "did the user arrive at the supermarket?" and uses much less battery than the most-precise setting.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Read the current permission state right now so the UI starts up with the right value (otherwise we'd briefly show ".notDetermined").
        authorization = Self.translate(manager.authorizationStatus)
        
        if manager.authorizationStatus == .authorizedWhenInUse ||
            manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    // Show the iOS permission prompt. Only does anything the first time.
    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    // Open the Settings app to this app's row.
    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // Convert Apple's permission enum into the app's simpler labels.
    private static func translate(_ status: CLAuthorizationStatus) -> LocationAuthorization {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorizedWhenInUse: return .foregroundOnly
        case .authorizedAlways: return .full
        @unknown default: return .denied
        }
    }
}

// MARK: - Geofencing

extension CoreLocationProvider: RegionMonitoring {

    // Tell iOS to start watching a circle. We give it a centre + radius and a unique id so we can identify it later.
    func startMonitoring(id: UUID, coordinate: LocationCoordinate, radius: Double) {
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ),
            radius: radius,
            identifier: id.uuidString
        )
        // We want notifications both when the user enters AND leaves.
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
        monitoredRegionIds.insert(id)
    }

    // Tell iOS to stop watching a circle. CoreLocation needs the actual region object back, so we look it up by id from its own list.
    func stopMonitoring(id: UUID) {
        let target = id.uuidString
        if let region = manager.monitoredRegions.first(where: { $0.identifier == target }) {
            manager.stopMonitoring(for: region)
        }
        monitoredRegionIds.remove(id)
    }
}

// MARK: - Apple's callbacks

extension CoreLocationProvider: CLLocationManagerDelegate {

    // React to permission changes and start location updates when allowed.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        
        print("Authorization Changed")
        print(manager.authorizationStatus.rawValue)
        
        authorization = Self.translate(manager.authorizationStatus)
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Without this call, no location updates would ever arrive.
            print("Starting location updates")
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    // Called whenever iOS has a new GPS fix. iOS sometimes batches several updates together, so we just take the most recent.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        guard let location = locations.last else { return }
        currentCoordinate = LocationCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    // User crossed into one of our geofence circles. Convert the region's identifier back to our UUID and tell whoever is listening.
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let id = UUID(uuidString: region.identifier) else { return }
        onRegionTransition?(id, .enter)
    }

    // User left one of our geofence circles.
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let id = UUID(uuidString: region.identifier) else { return }
        onRegionTransition?(id, .exit)
    }

    // Log location errors and keep the last known state.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("CoreLocationProvider error: \(error)")
    }
}
