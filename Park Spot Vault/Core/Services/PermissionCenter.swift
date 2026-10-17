import AVFoundation
import CoreLocation
import SwiftUI
import UserNotifications

final class PermissionCenter: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var locationStatus = "Not asked"
    @Published private(set) var cameraStatus = "Not asked"
    @Published private(set) var notificationStatus = "Not asked"
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
        refresh()
    }

    func refresh() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: locationStatus = "Allowed"
        case .denied, .restricted: locationStatus = "Off"
        default: locationStatus = "Not asked"
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: cameraStatus = "Allowed"
        case .denied, .restricted: cameraStatus = "Off"
        default: cameraStatus = "Not asked"
        }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral: self?.notificationStatus = "Allowed"
                case .denied: self?.notificationStatus = "Off"
                default: self?.notificationStatus = "Not asked"
                }
            }
        }
    }

    func requestLocation() {
        if locationStatus == "Off" { openSettings() }
        else { locationManager.requestWhenInUseAuthorization() }
    }

    func requestCamera() {
        if cameraStatus == "Off" { openSettings(); return }
        AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func requestNotifications() {
        if notificationStatus == "Off" { openSettings(); return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] _, _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { refresh() }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
