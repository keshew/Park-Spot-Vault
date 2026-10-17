import CoreLocation
import SwiftUI

final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var heading: Double?
    @Published private(set) var isLocating = false
    @Published private(set) var errorMessage: String?
    private let manager = CLLocationManager()
    private var wantsLocation = false
    private var continuous = false
    private var timeout: Task<Void, Never>?

    var coordinate: String {
        guard let location else { return "Not saved" }
        return String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
    }

    var accuracy: String {
        guard let location else { return "—" }
        return "±\(Int(location.horizontalAccuracy.rounded())) m"
    }

    var isAuthorized: Bool {
        manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 3
        manager.headingFilter = 2
    }

    func capture() { request(continuous: false) }

    func startTracking(requestPermission: Bool = true) {
        guard requestPermission || isAuthorized else { return }
        request(continuous: true)
    }

    func stop() {
        timeout?.cancel()
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        wantsLocation = false
        isLocating = false
    }

    private func request(continuous: Bool) {
        self.continuous = continuous
        wantsLocation = true
        errorMessage = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            beginUpdates()
        default:
            errorMessage = "Location access is off. Enable it in Settings, or save a photo and parking details instead."
            isLocating = false
        }
    }

    private func beginUpdates() {
        isLocating = true
        if continuous {
            manager.startUpdatingLocation()
        } else {
            manager.requestLocation()
        }
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
        timeout?.cancel()
        timeout = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: 15_000_000_000) } catch { return }
            guard let self, self.isLocating else { return }
            self.isLocating = false
            self.errorMessage = "No location fix yet. Try again outdoors, or save your parking details without GPS."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if wantsLocation && isAuthorized { beginUpdates() }
        else if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            stop()
            errorMessage = "Location access is off. You can still save a photo and parking details."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last, latest.horizontalAccuracy >= 0,
              abs(latest.timestamp.timeIntervalSinceNow) < 60 else { return }
        location = latest
        isLocating = false
        errorMessage = nil
        timeout?.cancel()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        timeout?.cancel()
        errorMessage = "Location is unavailable right now. Try again, or continue with a photo and notes."
    }

    func distance(to coordinate: CLLocationCoordinate2D) -> Double? {
        location?.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    func bearing(to coordinate: CLLocationCoordinate2D) -> Double? {
        guard let location else { return nil }
        let latitude = location.coordinate.latitude * .pi / 180
        let destination = coordinate.latitude * .pi / 180
        let delta = (coordinate.longitude - location.coordinate.longitude) * .pi / 180
        let y = sin(delta) * cos(destination)
        let x = cos(latitude) * sin(destination) - sin(latitude) * cos(destination) * cos(delta)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
}
