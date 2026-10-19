import AppKit
import Foundation
import UniformTypeIdentifiers

/// Persists roam events as JSON lines in Application Support, capped at `maxLines`.
@MainActor
final class EventLog: ObservableObject {
    static let maxLines = 10_000

    /// Events ordered newest first.
    @Published private(set) var events: [RoamEvent] = []
    @Published var lastError: String?

    private let fileURL: URL?
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    init() {
        let fm = FileManager.default
        if let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let dir = support.appendingPathComponent("WifiRoamLog", isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            fileURL = dir.appendingPathComponent("events.jsonl")
        } else {
            fileURL = nil
        }
        load()
    }

    private func load() {
        guard let url = fileURL, let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else { return }
        let parsed = text.split(separator: "\n").compactMap { line in
            try? decoder.decode(RoamEvent.self, from: Data(line.utf8))
        }
        events = Array(parsed.suffix(Self.maxLines).reversed())
    }

    func append(_ event: RoamEvent) {
        events.insert(event, at: 0)
        if events.count > Self.maxLines {
            events.removeLast(events.count - Self.maxLines)
            rewrite()
            return
        }
        guard let url = fileURL, var line = try? encoder.encode(event) else { return }
        line.append(0x0A)
        do {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
            } else {
                try line.write(to: url, options: .atomic)
            }
        } catch {
            lastError = "Could not write log: \(error.localizedDescription)"
        }
    }

    func clear() {
        events.removeAll()
        rewrite()
    }

    /// Writes the full in-memory log back to disk (oldest first).
    private func rewrite() {
        guard let url = fileURL else { return }
        var data = Data()
        for event in events.reversed() {
            if let line = try? encoder.encode(event) {
                data.append(line)
                data.append(0x0A)
            }
        }
        do { try data.write(to: url, options: .atomic) } catch {
            lastError = "Could not save log: \(error.localizedDescription)"
        }
    }

    /// Plain-text rendering used for export.
    func exportText() -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        return events.map { e in
            "\(fmt.string(from: e.date))\t\(e.type.rawValue)\t\(e.oldValue)\t\(e.newValue)\t\(e.note)"
        }.joined(separator: "\n") + "\n"
    }

    func exportWithPanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "WifiRoamLog.txt"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try exportText().write(to: url, atomically: true, encoding: .utf8) } catch {
            lastError = "Export failed: \(error.localizedDescription)"
        }
    }
}
