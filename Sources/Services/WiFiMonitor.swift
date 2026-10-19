import AppKit
import CoreWLAN
import UserNotifications

/// Polls the built-in Wi-Fi interface, keeps an in-memory sample history and logs radio changes.
@MainActor
final class WiFiMonitor: ObservableObject {
    /// Overall state of the Wi-Fi hardware as seen by the app.
    enum InterfaceState: Equatable { case active, poweredOff, noInterface }

    @Published private(set) var samples: [WiFiSample] = []
    @Published private(set) var current: WiFiSample?
    @Published private(set) var state: InterfaceState = .active

    let log: EventLog
    private let client = CWWiFiClient.shared()
    private var timer: Timer?
    private var tick = 0
    private var isAsleep = false
    private var previous: WiFiSample?
    private var observers: [NSObjectProtocol] = []

    init(log: EventLog) {
        self.log = log
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isAsleep = true }
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.handleWake() }
        })
        start()
    }

    deinit {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    private var defaults: UserDefaults { .standard }
    private var pollInterval: Int { [1, 2, 5].contains(defaults.integer(forKey: SettingsKey.pollInterval)) ? defaults.integer(forKey: SettingsKey.pollInterval) : 1 }
    private var historyMinutes: Int { max(5, defaults.object(forKey: SettingsKey.historyMinutes) as? Int ?? 60) }

    /// A 1 s base timer; actual polling happens every `pollInterval` ticks so setting changes apply live.
    func start() {
        timer?.invalidate()
        poll()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.onTick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func onTick() {
        guard !isAsleep else { return }
        tick += 1
        if tick % pollInterval == 0 { poll() }
    }

    private func handleWake() {
        isAsleep = false
        log.append(RoamEvent(date: Date(), type: .wake, oldValue: "Sleep", newValue: "Awake", note: "Mac woke from sleep; polling resumed"))
        previous = nil
        poll()
    }

    /// Reads the first Wi-Fi interface, stores a sample and compares it with the previous one.
    func poll() {
        guard let iface = client.interface() ?? client.interfaces()?.first else {
            state = .noInterface
            current = nil
            return
        }
        guard iface.powerOn() else {
            if state != .poweredOff, let prev = previous, prev.isConnected {
                record(.disconnected, old: prev.ssid ?? "Unknown", new: "Off", note: "Wi-Fi was turned off")
            }
            state = .poweredOff
            current = nil
            previous = nil
            return
        }
        state = .active
        let wlan = iface.wlanChannel()
        let sample = WiFiSample(
            date: Date(), ssid: iface.ssid(), bssid: iface.bssid(),
            rssi: iface.rssiValue(), noise: iface.noiseMeasurement(), rate: iface.transmitRate(),
            channel: wlan.map { $0.channelNumber }, band: wlan.flatMap { Self.bandName($0.channelBand) })
        current = sample
        samples.append(sample)
        let cutoff = Date().addingTimeInterval(-Double(historyMinutes) * 60)
        if let firstKeep = samples.firstIndex(where: { $0.date >= cutoff }), firstKeep > 0 {
            samples.removeFirst(firstKeep)
        }
        if let prev = previous { detectChanges(from: prev, to: sample) }
        previous = sample
    }

    private func detectChanges(from old: WiFiSample, to new: WiFiSample) {
        switch (old.isConnected, new.isConnected) {
        case (true, false):
            record(.disconnected, old: old.ssid ?? "Unknown", new: "—", note: "Disconnected from \(old.ssid ?? "network")")
            return
        case (false, true):
            record(.connected, old: "—", new: new.ssid ?? "Unknown", note: "Connected on channel \(new.channel.map(String.init) ?? "?")")
            return
        case (false, false):
            return
        case (true, true):
            break
        }
        if let a = old.ssid, let b = new.ssid, a != b {
            record(.network, old: a, new: b, note: "Switched network from \(a) to \(b)")
        } else if let a = old.bssid, let b = new.bssid, a != b {
            let ch = old.channel != new.channel ? " (channel \(Self.str(old.channel)) → \(Self.str(new.channel)))" : ""
            record(.roam, old: a, new: b, note: "Roamed to another access point\(ch)", notify: true)
        } else if old.channel != new.channel {
            record(.channel, old: Self.str(old.channel), new: Self.str(new.channel),
                   note: "Roamed from channel \(Self.str(old.channel)) to channel \(Self.str(new.channel))", notify: true)
        }
        if old.band != new.band, let a = old.band, let b = new.band {
            record(.band, old: a, new: b, note: "Band changed from \(a) to \(b)")
        }
    }

    private func record(_ type: RoamEventType, old: String, new: String, note: String, notify: Bool = false) {
        log.append(RoamEvent(date: Date(), type: type, oldValue: old, newValue: new, note: note))
        if notify && defaults.bool(forKey: SettingsKey.notifyOnRoam) { Self.sendNotification(note) }
    }

    static func sendNotification(_ body: String) {
        let content = UNMutableNotificationContent()
        content.title = "Wi-Fi Roam"
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private static func str(_ v: Int?) -> String { v.map(String.init) ?? "?" }

    private static func bandName(_ band: CWChannelBand) -> String? {
        switch band {
        case .band2GHz: return "2.4 GHz"
        case .band5GHz: return "5 GHz"
        case .band6GHz: return "6 GHz"
        default: return nil
        }
    }
}
