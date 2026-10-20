import Foundation

@MainActor
final class Store: ObservableObject {
    enum Stopping { case terminating, stubborn }

    @Published private(set) var listeners: [Listener] = []
    @Published private(set) var stopping: [Int32: Stopping] = [:]
    @Published var error: String?

    private let demo: Bool

    init(demo listeners: [Listener]? = nil, stopping: [Int32: Stopping] = [:]) {
        self.demo = listeners != nil
        self.listeners = listeners ?? []
        self.stopping = stopping
    }

    func refresh() {
        guard !demo else { return }
        Task.detached(priority: .userInitiated) {
            let result = Scanner.scan()
            await MainActor.run { self.listeners = result }
        }
    }

    /// SIGTERM, then after 2 s either the process is gone (refresh) or we offer SIGKILL.
    func stop(_ l: Listener) {
        let force = stopping[l.pid] == .stubborn
        if let message = Signals.send(l.pid, force: force) {
            error = "\(l.name) (\(l.pid)): \(message)"
            return
        }
        error = nil
        stopping[l.pid] = .terminating
        Task {
            try? await Task.sleep(for: .seconds(force ? 0.5 : 2))
            if Signals.isAlive(l.pid) {
                stopping[l.pid] = .stubborn
            } else {
                stopping[l.pid] = nil
                refresh()
            }
        }
    }

    func stopAll(_ ls: [Listener]) {
        ls.forEach(stop)
    }
}
