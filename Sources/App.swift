import SwiftUI
import AppKit

/// Entry point: a menu bar extra plus Log and Settings windows.
@main
struct WifiRoamLogApp: App {
    @StateObject private var log: EventLog
    @StateObject private var monitor: WiFiMonitor
    @StateObject private var location = LocationAuthorizer()
    @AppStorage(SettingsKey.menuFormat) private var menuFormat = MenuFormat.dBm.rawValue

    init() {
        let log = EventLog()
        _log = StateObject(wrappedValue: log)
        _monitor = StateObject(wrappedValue: WiFiMonitor(log: log))
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(monitor)
                .environmentObject(location)
        } label: {
            Image(systemName: monitor.current?.isConnected == true ? "wifi" : "wifi.slash")
            Text(menuText)
        }
        .menuBarExtraStyle(.window)

        Window("Roam Log", id: "log") {
            LogView().environmentObject(log)
        }
        .defaultSize(width: 760, height: 460)

        Window("WifiRoamLog Settings", id: "settings") {
            SettingsView().environmentObject(location)
        }
        .windowResizability(.contentSize)
    }

    private var menuText: String {
        guard let s = monitor.current, s.isConnected else { return monitor.state == .poweredOff ? "Off" : "—" }
        switch MenuFormat(rawValue: menuFormat) ?? .dBm {
        case .dBm: return "\(s.rssi) dBm · \(Int(s.rate)) Mbps"
        case .percentage: return "\(s.percent)%"
        case .rating: return s.quality.rawValue
        }
    }
}

/// Shared helpers for opening external destinations.
enum Links {
    static func donate() {
        NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
    }

    static func networkSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
