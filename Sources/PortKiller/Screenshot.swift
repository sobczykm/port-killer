import AppKit
import SwiftUI

/// `PortKiller --screenshot <dir>` renders the menu with sample data into light.png and dark.png (README images).
@MainActor
enum Screenshot {
    static func render(into dir: String) {
        let ago = { (minutes: Double) in Date().addingTimeInterval(-minutes * 60) }
        let sample = [
            Listener(pid: 4211, name: "node", ports: [Port(number: 3000, exposed: false)], path: "/opt/homebrew/bin/node", started: ago(42), project: "storefront"),
            Listener(pid: 4380, name: "node", ports: [Port(number: 5173, exposed: false), Port(number: 24678, exposed: false)], path: "/opt/homebrew/bin/node", started: ago(38), project: "design-system"),
            Listener(pid: 5102, name: "api", ports: [Port(number: 8080, exposed: true)], path: "/Users/dev/billing-service/bin/api", started: ago(7), project: "billing-service"),
            Listener(pid: 912, name: "com.docker.backend", ports: [Port(number: 5432, exposed: false), Port(number: 6379, exposed: false)], path: "/Applications/Docker.app/Contents/MacOS/com.docker.backend", started: ago(60 * 26), project: "Docker"),
            Listener(pid: 6033, name: "kubectl", ports: [Port(number: 9090, exposed: false)], path: "/opt/homebrew/bin/kubectl", started: ago(3), project: "port-forward svc/grafana 9090:80 -n monitoring"),
        ]
        for (file, appearance) in [("light.png", NSAppearance.Name.aqua), ("dark.png", .darkAqua)] {
            let store = Store(demo: sample, stopping: [5102: .stubborn])
            let view = NSHostingView(rootView: MenuView()
                .environmentObject(store)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.12)))
                .padding(1))
            let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: appearance)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.contentView = view
            window.setContentSize(view.fittingSize)
            window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
            window.orderFrontRegardless()
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))

            guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
            view.cacheDisplay(in: view.bounds, to: rep)
            let url = URL(fileURLWithPath: dir).appendingPathComponent(file)
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
            print(url.path)
            window.close()
        }
    }
}
