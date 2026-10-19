import SwiftUI
import Charts

/// Content of the menu bar window: header, quality, three live charts and actions.
struct PopoverView: View {
    @EnvironmentObject private var monitor: WiFiMonitor
    @EnvironmentObject private var location: LocationAuthorizer
    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.seenIntro) private var seenIntro = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !seenIntro && !location.isAuthorized {
                IntroView(seenIntro: $seenIntro)
            } else {
                switch monitor.state {
                case .noInterface:
                    message("wifi.exclamationmark", "No Wi-Fi interface found",
                            "WifiRoamLog reads the Mac's built-in Wi-Fi. External USB Wi-Fi adapters are not supported.")
                case .poweredOff:
                    message("wifi.slash", "Wi-Fi is off", "Turn Wi-Fi on to start graphing.")
                    Button("Open Network Settings") { Links.networkSettings() }
                case .active:
                    header
                    ChartsView(samples: monitor.samples)
                }
            }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 380)
    }

    private var header: some View {
        let s = monitor.current
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(s?.isConnected == true ? (s?.ssid ?? "Unknown network") : "Not connected")
                    .font(.headline)
                Spacer()
                if let s, s.isConnected {
                    Text(s.quality.rawValue)
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(color(for: s.quality).opacity(0.2), in: Capsule())
                        .foregroundStyle(color(for: s.quality))
                }
            }
            if let s, s.isConnected {
                Text("\(s.band ?? "—") · Channel \(s.channel.map(String.init) ?? "?") · BSSID \(s.bssid ?? "Unknown")")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 14) {
                    stat("Signal", "\(s.rssi) dBm")
                    stat("Noise", "\(s.noise) dBm")
                    stat("SNR", "\(s.snr) dB")
                    stat("Rate", "\(Int(s.rate)) Mbps")
                }
            }
            if !location.isAuthorized {
                HStack {
                    Text("Network name hidden without Location access.").font(.caption2).foregroundStyle(.secondary)
                    Button(location.isDenied ? "Open Settings" : "Allow") {
                        location.isDenied ? location.openPrivacySettings() : location.request()
                    }
                    .controlSize(.mini)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Log") { openWindow(id: "log"); NSApp.activate(ignoringOtherApps: true) }
            Button("Settings") { openWindow(id: "settings"); NSApp.activate(ignoringOtherApps: true) }
            Button("Support / Donate ❤️") { Links.donate() }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
        }
        .controlSize(.small)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.callout.monospacedDigit())
        }
    }

    private func message(_ symbol: String, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol).font(.headline)
            Text(detail).font(.callout).foregroundStyle(.secondary)
        }
    }

    private func color(for q: SignalQuality) -> Color {
        switch q {
        case .poor: return .red
        case .fair: return .orange
        case .good: return .green
        case .excellent: return .blue
        }
    }
}

/// Three stacked line charts for signal, noise and transmit rate.
struct ChartsView: View {
    let samples: [WiFiSample]

    var body: some View {
        let connected = samples.filter(\.isConnected)
        VStack(spacing: 6) {
            chart("Signal (dBm)", connected.map { ($0.date, Double($0.rssi)) }, .blue)
            chart("Noise (dBm)", connected.map { ($0.date, Double($0.noise)) }, .gray)
            chart("Tx Rate (Mbps)", connected.map { ($0.date, $0.rate) }, .purple)
        }
    }

    private func chart(_ title: String, _ points: [(Date, Double)], _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Chart(points.indices, id: \.self) { i in
                LineMark(x: .value("Time", points[i].0), y: .value(title, points[i].1))
                    .foregroundStyle(color)
                    .interpolationMethod(.monotone)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis(.hidden)
            .frame(height: 70)
            .overlay {
                if points.isEmpty { Text("Waiting for data…").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
}

/// First-run explanation of why Location access is requested.
struct IntroView: View {
    @EnvironmentObject private var location: LocationAuthorizer
    @Binding var seenIntro: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Welcome to WifiRoamLog", systemImage: "wifi").font(.headline)
            Text("macOS only reveals the Wi-Fi network name and access point identifier to apps with Location access. WifiRoamLog never stores or shares your location — it only uses the permission to read those two values so it can log roams.")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            Text("Without it, signal, noise, rate and channel changes are still graphed and logged; the network name shows as Unknown.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Allow Location Access") { location.request(); seenIntro = true }
                    .buttonStyle(.borderedProminent)
                Button("Not Now") { seenIntro = true }
            }
        }
    }
}
