import Foundation
import SwiftUI

@main
struct PortKillerApp: App {
    @StateObject private var store = Store()

    init() {
        // `PortKiller --list`: print what the menu would show (debugging without UI)
        if CommandLine.arguments.contains("--list") {
            for l in Scanner.scan() {
                let ports = l.ports.map { ":\($0.number)\($0.exposed ? "*" : "")" }.joined(separator: " ")
                print("\(ports)\t\(l.isSystem ? "[sys] " : "")\(l.project ?? l.name)\t\(l.name) \(l.pid)\t\(l.path ?? "?")\tcwd=\(l.cwd ?? "?")")
            }
            exit(0)
        }
        if let i = CommandLine.arguments.firstIndex(of: "--screenshot") {
            let dir = CommandLine.arguments.indices.contains(i + 1) ? CommandLine.arguments[i + 1] : "."
            MainActor.assumeIsolated { Screenshot.render(into: dir) }
            exit(0)
        }
    }

    var body: some Scene {
        MenuBarExtra("PortKiller", systemImage: "network") {
            MenuView().environmentObject(store)
        }
        .menuBarExtraStyle(.window)
    }
}
