//
//  CoreLocationProvider.swift
//  contextReminder
//
//  The real-app location provider. Talks to Apple's CLLocationManager
//  (the iPhone's GPS + permission system) and translates everything into
//  our own simpler types so the rest of the app doesn't need to know about
//  CoreLocation at all.
//

import Foundation
import Combine
import CoreLocation
import UIKit

final class CoreLocationProvider: NSObject, LocationProviding {

    /// Current permission state. Always updated on the main thread so SwiftUI
    /// redraws immediately when the user responds to a permission prompt.
    @Published private(set) var authorization: LocationAuthorization = .notDetermined

    /// Latest known coordinate. Nil until permission is granted and a GPS fix arrives.
    @Published private(set) var currentCoordinate: LocationCoordinate?

    /// IDs of every geofence circle we've asked iOS to watch.
    private(set) var monitoredRegionIds: Set<UUID> = []

    /// Called whenever a geofence fires (user enters or leaves a circle).
    var onRegionTransition: ((UUID, RegionTransition) -> Void)?

    /// The actual Apple object that does the GPS work.
    /// Must be created on the main thread — CLLocationManager requires it.
    private let manager: CLLocationManager

    override init() {
        // CLLocationManager must be created on the main thread.
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // Seed the initial auth state synchronously so the UI is correct
        // on the very first frame (no .notDetermined flash).
        authorization = Self.translate(manager.authorizationStatus)
    }

    // MARK: - Permission requests

    func requestWhenInUseAuthorization() {
        // CLLocationManager methods must be called on the main thread.
        DispatchQueue.main.async {
            self.manager.requestWhenInUseAuthorization()
        }
    }

    func requestAlwaysAuthorization() {
        DispatchQueue.main.async {
            self.manager.requestAlwaysAuthorization()
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Translation

    private static func translate(_ status: CLAuthorizationStatus) -> LocationAuthorization {
        switch status {
        case .notDetermined:       return .notDetermined
        case .restricted:          return .restricted
        case .denied:              return .denied
        case .authorizedWhenInUse: return .foregroundOnly
        case .authorizedAlways:    return .full
        @unknown default:          return .denied
        }
    }
}

// MARK: - Geofencing

extension CoreLocationProvider: RegionMonitoring {

    func startMonitoring(id: UUID, coordinate: LocationCoordinate, radius: Double) {
        let region = CLCircularRegion(
            center: CLLocationCoordinate2D(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            ),
            radius: radius,
            identifier: id.uuidString
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
        monitoredRegionIds.insert(id)
    }

    func stopMonitoring(id: UUID) {
        let target = id.uuidString
        if let region = manager.monitoredRegions.first(where: { $0.identifier == target }) {
            manager.stopMonitoring(for: region)
        }
        monitoredRegionIds.remove(id)
    }
}

// MARK: - CLLocationManagerDelegate

extension CoreLocationProvider: CLLocationManagerDelegate {

    /// This is the key callback — iOS calls it after the user responds to a
    /// permission prompt. MUST update @Published properties on the main thread
    /// or SwiftUI won't redraw.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newAuth = Self.translate(manager.authorizationStatus)
        DispatchQueue.main.async {
            self.authorization = newAuth
        }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coord = LocationCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        DispatchQueue.main.async {
            self.currentCoordinate = coord
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let id = UUID(uuidString: region.identifier) else { return }
        onRegionTransition?(id, .enter)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let id = UUID(uuidString: region.identifier) else { return }
        onRegionTransition?(id, .exit)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("CoreLocationProvider error: \(error)")
    }
}
