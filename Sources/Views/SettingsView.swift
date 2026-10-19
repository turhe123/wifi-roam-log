import SwiftUI
import ServiceManagement

/// User preferences: menu bar format, polling, notifications, history and launch at login.
struct SettingsView: View {
    @EnvironmentObject private var location: LocationAuthorizer
    @AppStorage(SettingsKey.menuFormat) private var menuFormat = MenuFormat.dBm.rawValue
    @AppStorage(SettingsKey.pollInterval) private var pollInterval = 1
    @AppStorage(SettingsKey.notifyOnRoam) private var notifyOnRoam = false
    @AppStorage(SettingsKey.historyMinutes) private var historyMinutes = 60
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Picker("Menu bar shows", selection: $menuFormat) {
                ForEach(MenuFormat.allCases) { Text($0.label).tag($0.rawValue) }
            }
            Picker("Polling interval", selection: $pollInterval) {
                Text("1 second").tag(1)
                Text("2 seconds").tag(2)
                Text("5 seconds").tag(5)
            }
            Picker("History length", selection: $historyMinutes) {
                Text("15 minutes").tag(15)
                Text("30 minutes").tag(30)
                Text("1 hour").tag(60)
            }
            Toggle("Notify on roam", isOn: $notifyOnRoam)
                .onChange(of: notifyOnRoam) { _, on in if on { WiFiMonitor.requestNotificationPermission() } }
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
            if let loginError {
                Text(loginError).font(.caption).foregroundStyle(.red)
            }
            LabeledContent("Location access") {
                if location.isAuthorized {
                    Text("Granted").foregroundStyle(.green)
                } else if location.isDenied {
                    Button("Open Privacy Settings") { location.openPrivacySettings() }
                } else {
                    Button("Request Access") { location.request() }
                }
            }
            HStack {
                Spacer()
                Button("Support / Donate ❤️") { Links.donate() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Could not update login item: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
