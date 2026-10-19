import Foundation

/// One reading of the Wi-Fi radio taken by `WiFiMonitor`.
struct WiFiSample: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let ssid: String?
    let bssid: String?
    let rssi: Int
    let noise: Int
    let rate: Double
    let channel: Int?
    let band: String?

    /// macOS reports an RSSI of zero when the interface is not associated.
    var isConnected: Bool { rssi != 0 }
    var snr: Int { rssi - noise }
    var quality: SignalQuality { SignalQuality(snr: snr) }

    /// Rough RSSI → percentage mapping (-100 dBm = 0 %, -50 dBm = 100 %).
    var percent: Int { max(0, min(100, 2 * (rssi + 100))) }
}

/// Word rating derived from the signal-to-noise ratio.
enum SignalQuality: String {
    case poor = "Poor", fair = "Fair", good = "Good", excellent = "Excellent"

    init(snr: Int) {
        switch snr {
        case ..<15: self = .poor
        case 15..<25: self = .fair
        case 25..<40: self = .good
        default: self = .excellent
        }
    }
}

/// Kind of change recorded in the roam log.
enum RoamEventType: String, Codable, CaseIterable {
    case network = "Network"
    case roam = "Roam"
    case channel = "Channel"
    case band = "Band"
    case connected = "Connected"
    case disconnected = "Disconnected"
    case wake = "Wake"
}

/// A single persisted log entry describing a radio-level change.
struct RoamEvent: Identifiable, Codable, Equatable {
    var id = UUID()
    let date: Date
    let type: RoamEventType
    let oldValue: String
    let newValue: String
    let note: String
}

/// Keys and option values for user settings stored in `UserDefaults`.
enum SettingsKey {
    static let menuFormat = "menuFormat"
    static let pollInterval = "pollInterval"
    static let notifyOnRoam = "notifyOnRoam"
    static let historyMinutes = "historyMinutes"
    static let seenIntro = "seenIntro"
}

/// How the menu bar status text is rendered.
enum MenuFormat: String, CaseIterable, Identifiable {
    case dBm, percentage, rating
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dBm: return "dBm + rate"
        case .percentage: return "Percentage"
        case .rating: return "Rating"
        }
    }
}
