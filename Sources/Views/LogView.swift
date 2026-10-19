import SwiftUI

/// Table of logged events, newest first, with Clear and Export actions.
struct LogView: View {
    @EnvironmentObject private var log: EventLog
    @State private var confirmClear = false

    var body: some View {
        Table(log.events) {
            TableColumn("Time") { e in
                Text(e.date.formatted(date: .abbreviated, time: .standard)).monospacedDigit()
            }
            .width(min: 140, ideal: 170)
            TableColumn("Event") { e in Text(e.type.rawValue) }.width(min: 70, ideal: 90)
            TableColumn("Old Value") { e in Text(e.oldValue) }
            TableColumn("New Value") { e in Text(e.newValue) }
            TableColumn("Note") { e in Text(e.note).foregroundStyle(.secondary) }
        }
        .overlay {
            if log.events.isEmpty {
                ContentUnavailableView("No events yet", systemImage: "list.bullet.rectangle",
                                       description: Text("Roams, channel and band changes will appear here."))
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button { confirmClear = true } label: { Label("Clear", systemImage: "trash") }
                    .disabled(log.events.isEmpty)
                Button { log.exportWithPanel() } label: { Label("Export", systemImage: "square.and.arrow.up") }
                    .disabled(log.events.isEmpty)
            }
        }
        .confirmationDialog("Clear the entire log?", isPresented: $confirmClear) {
            Button("Clear Log", role: .destructive) { log.clear() }
        }
        .alert("Error", isPresented: Binding(get: { log.lastError != nil }, set: { if !$0 { log.lastError = nil } })) {
            Button("OK") { log.lastError = nil }
        } message: {
            Text(log.lastError ?? "")
        }
        .frame(minWidth: 600, minHeight: 300)
    }
}
