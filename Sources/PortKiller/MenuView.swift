import AppKit
import SwiftUI

struct MenuView: View {
    @EnvironmentObject var store: Store
    @AppStorage("showSystem") private var showSystem = false
    @State private var confirmAll = false

    private var visible: [Listener] { store.listeners.filter { showSystem || !$0.isSystem } }
    private var hiddenCount: Int { store.listeners.count - store.listeners.filter { !$0.isSystem }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Nasłuchujące porty").font(.headline)
                Spacer()
                Button { store.refresh() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .help("Odśwież")
            }
            .padding(12)

            Divider()

            if visible.isEmpty {
                Text("Nic nie nasłuchuje").foregroundStyle(.secondary).padding(12)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(visible) { l in
                            Row(listener: l, state: store.stopping[l.pid]) { store.stop(l) }
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .frame(maxHeight: 440)
                .fixedSize(horizontal: false, vertical: true)
            }

            if let error = store.error {
                Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal, 12).padding(.top, 8)
            }

            HStack {
                Toggle("Systemowe (\(hiddenCount))", isOn: $showSystem)
                    .toggleStyle(.checkbox)
                    .font(.caption)
                Spacer()
                if visible.count > 1 {
                    Button(confirmAll ? "Na pewno?" : "Zatrzymaj wszystkie") {
                        if confirmAll {
                            store.stopAll(visible)
                            confirmAll = false
                        } else {
                            confirmAll = true
                            Task { try? await Task.sleep(for: .seconds(3)); confirmAll = false }
                        }
                    }
                    .tint(confirmAll ? .red : nil)
                }
                Button("Zakończ") { NSApp.terminate(nil) }
            }
            .controlSize(.small)
            .padding(12)
        }
        .frame(width: 380)
        .onAppear { store.refresh() }
        // the MenuBarExtra window is reused, onAppear fires only the first time
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            store.refresh()
        }
    }
}

private struct Row: View {
    let listener: Listener
    let state: Store.Stopping?
    let stop: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    ForEach(listener.ports, id: \.number) { port in
                        Button {
                            NSWorkspace.shared.open(URL(string: "http://localhost:\(port.number)")!)
                        } label: {
                            HStack(spacing: 2) {
                                Text(":\(String(port.number))").monospacedDigit()
                                if port.exposed { Image(systemName: "globe").imageScale(.small) }
                            }
                        }
                        .buttonStyle(.borderless)
                        .font(.system(.body, design: .monospaced).weight(.semibold))
                        .help(port.exposed ? "Dostępny z sieci (nasłuchuje na wszystkich interfejsach). Kliknij, by otworzyć." : "Otwórz w przeglądarce")
                    }
                }
                Text(listener.project ?? listener.name).lineLimit(1).truncationMode(.middle)
                Text(details).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
            switch state {
            case .terminating:
                ProgressView().controlSize(.small)
            case .stubborn:
                Button("Wymuś", role: .destructive, action: stop)
                    .tint(.red)
                    .controlSize(.small)
                    .help("Proces nie zakończył się po SIGTERM — wyślij SIGKILL")
            case nil:
                Button(action: stop) { Image(systemName: "xmark.circle.fill").imageScale(.large) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Zatrzymaj (SIGTERM)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .help([listener.args, listener.cwd.map { "cwd: \($0)" }].compactMap { $0 }.joined(separator: "\n"))
    }

    private var details: String {
        var parts = [listener.name, "PID \(listener.pid)"]
        if let started = listener.started { parts.append(uptime(since: started)) }
        return parts.joined(separator: " · ")
    }
}

func uptime(since date: Date) -> String {
    let s = Int(Date().timeIntervalSince(date))
    switch s {
    case ..<60: return "\(s) s"
    case ..<3600: return "\(s / 60) min"
    case ..<86400: return "\(s / 3600) h \(s % 3600 / 60) min"
    default: return "\(s / 86400) d"
    }
}
