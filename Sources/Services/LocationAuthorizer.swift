import CoreLocation
import AppKit

/// Requests When-In-Use location access, which macOS requires before CoreWLAN reveals SSID/BSSID.
@MainActor
final class LocationAuthorizer: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var status: CLAuthorizationStatus
    private let manager = CLLocationManager()

    override init() {
        status = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    var isAuthorized: Bool { status == .authorizedAlways || status == .authorized }
    var isDenied: Bool { status == .denied || status == .restricted }

    func request() {
        NSApp.activate(ignoringOtherApps: true)
        manager.requestWhenInUseAuthorization()
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor in self.status = newStatus }
    }
}
