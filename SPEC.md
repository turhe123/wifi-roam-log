# WifiRoamLog — specification

**Tagline:** Graph Wi-Fi signal, noise and rate live and keep a log of every roam and channel change.

**Category:** System Monitoring

**Inspired by (paid):** WiFi Signal ($4.99 one-time)

**Frameworks:** SwiftUI, AppKit, CoreWLAN, CoreLocation, Charts, ServiceManagement

**Donation URL (Support button):** https://ko-fi.com/leodavidai

## Spec

What the paid app does: WiFi Signal from Intuitibits sells for 4.99 dollars on the Mac App Store. It shows a configurable menu bar status line, real time graphs of signal, noise, signal to noise ratio and transmit rate, quality ratings, and notifications and logs when the Mac roams or changes channel. It targets people debugging flaky wireless and is a long running paid utility in the category. Our clean-room version avoids duplicating pure latency checks and instead centers on radio level history and event logging.

Feature set: Poll the current Wi-Fi interface once per second. Show in the menu bar a short text such as the signal in dBm and rate. Store the last hour of samples in memory and draw three stacked line charts for signal, noise and transmit rate. Compute signal to noise ratio and map it to a word rating of Poor, Fair, Good or Excellent. Detect events when the network name, access point identifier, channel or band changes, and append each event with a timestamp to a log that is kept on disk. The log view lists events newest first with a note such as roamed from channel 36 to channel 149. Export the log as a text file. Optional notification on each roam.

UI spec: MenuBarExtra in window style. The popover has a header with network name, band and channel, current signal and noise, the quality rating, the three charts and a Log button. A Log window shows a table with time, event type, old value and new value and a Clear and Export toolbar. Settings window fields: menu bar format picker with dBm, percentage or rating, polling interval of one, two or five seconds, notify on roam toggle, history length and launch at login. When Wi-Fi is off the popover shows a Wi-Fi is off message with a button that opens Network settings.

Technical approach: Use CWWiFiClient shared client and its default interface to read rssiValue, noiseMeasurement, transmitRate, channel through wlanChannel and ssid. Newer macOS versions hide the network name and the access point identifier unless the app has location authorization, so request When In Use location authorization through CLLocationManager with a clear purpose string and explain why in the first run view. Without permission, the app still graphs numbers and logs channel changes, only showing Unknown for name. Charts are drawn with Swift Charts. Event detection compares consecutive samples. The log is stored as a JSON lines file in Application Support. Settings use AppStorage and launch at login uses SMAppService.

Edge cases: Multiple interfaces are handled by choosing the first Wi-Fi interface. Samples with a zero rssi are treated as disconnected. Log growth is capped at ten thousand lines with the oldest trimmed. Sleep and wake pause polling and add a wake marker. External Wi-Fi adapters are not supported and the app says so when no interface is found.
