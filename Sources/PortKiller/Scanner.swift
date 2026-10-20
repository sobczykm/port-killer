import Darwin
import Foundation

struct Port: Hashable, Comparable {
    let number: Int
    /// Listening on a non-loopback address, i.e. reachable from the network.
    let exposed: Bool

    static func < (a: Port, b: Port) -> Bool { a.number < b.number }
}

struct Listener: Identifiable {
    let pid: Int32
    let name: String
    var ports: [Port]
    var path: String?
    var cwd: String?
    var args: String?
    var started: Date?
    var project: String?

    var id: Int32 { pid }

    /// macOS services and helpers of GUI apps (AirPlay, VS Code, …) — hidden by default.
    var isSystem: Bool {
        guard let path else { return true }
        if Self.alwaysShown.contains(where: { path.lowercased().contains($0) }) { return false }
        // .app bundles only from /Applications — Homebrew's Python also lives in a Python.app
        let apps = ["/Applications/", FileManager.default.homeDirectoryForCurrentUser.path + "/Applications/"]
        return ["/System/", "/usr/libexec/", "/usr/sbin/", "/Library/Apple/"].contains(where: path.hasPrefix)
            || (apps.contains(where: path.hasPrefix) && path.contains(".app/Contents/"))
    }

    private static let alwaysShown = ["docker", "orbstack", "ollama", "postgres"]
}

enum Scanner {
    static func scan() -> [Listener] {
        var byPid: [Int32: Listener] = [:]
        var order: [Int32] = []
        var current: Int32 = 0

        // -F: one field per line, prefixed with p (pid), c (command), n (address)
        for line in run("/usr/sbin/lsof", "-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn").split(separator: "\n") {
            let value = String(line.dropFirst())
            switch line.first {
            case "p":
                current = Int32(value) ?? 0
                if byPid[current] == nil { order.append(current) }
            case "c":
                byPid[current] = Listener(pid: current, name: value, ports: [])
            case "n":
                guard let colon = value.lastIndex(of: ":"), let number = Int(value[value.index(after: colon)...]) else { continue }
                let host = value[..<colon]
                let loopback = host.hasPrefix("127.") || host == "[::1]" || host == "localhost"
                let port = Port(number: number, exposed: !loopback)
                // IPv4 and IPv6 sockets on the same port count once; exposed wins
                if let i = byPid[current]?.ports.firstIndex(where: { $0.number == number }) {
                    if port.exposed { byPid[current]?.ports[i] = port }
                } else {
                    byPid[current]?.ports.append(port)
                }
            default: break
            }
        }

        let args = arguments(order)
        return order.compactMap { pid -> Listener? in
            guard var l = byPid[pid] else { return nil }
            l.ports.sort()
            l.path = executablePath(pid)
            l.cwd = workingDirectory(pid)
            l.started = startDate(pid)
            l.args = args[pid]
            l.project = project(cwd: l.cwd, args: l.args)
            return l
        }
        .sorted { ($0.ports.first?.number ?? 0) < ($1.ports.first?.number ?? 0) }
    }

    // MARK: process details

    private static func executablePath(_ pid: Int32) -> String? {
        var buf = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        return proc_pidpath(pid, &buf, UInt32(buf.count)) > 0 ? String(cString: buf) : nil
    }

    private static func workingDirectory(_ pid: Int32) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafeBytes(of: info.pvi_cdir.vip_path) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
        return path.isEmpty ? nil : path
    }

    private static func startDate(_ pid: Int32) -> Date? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec))
    }

    /// Full command lines, one `ps` call for all pids.
    private static func arguments(_ pids: [Int32]) -> [Int32: String] {
        guard !pids.isEmpty else { return [:] }
        var result: [Int32: String] = [:]
        let out = run("/bin/ps", "-o", "pid=,args=", "-p", pids.map(String.init).joined(separator: ","))
        for line in out.split(separator: "\n") {
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
            if parts.count == 2, let pid = Int32(parts[0]) { result[pid] = String(parts[1]) }
        }
        return result
    }

    /// Name of the project the process runs in: the nearest directory with .git / package.json / go.mod,
    /// or the working directory itself. `kubectl port-forward` shows its target instead.
    private static func project(cwd: String?, args: String?) -> String? {
        if let args, let r = args.range(of: "port-forward ") {
            return "port-forward " + args[r.upperBound...]
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        guard let cwd, cwd != "/", cwd != home else { return nil }
        var dir = URL(fileURLWithPath: cwd)
        while dir.path.hasPrefix(home + "/") {
            for marker in [".git", "package.json", "go.mod"]
            where FileManager.default.fileExists(atPath: dir.appendingPathComponent(marker).path) {
                return dir.lastPathComponent
            }
            dir.deleteLastPathComponent()
        }
        return URL(fileURLWithPath: cwd).lastPathComponent
    }

    private static func run(_ tool: String, _ arguments: String...) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = arguments
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}

enum Signals {
    /// nil on success, otherwise a message for the user.
    static func send(_ pid: Int32, force: Bool) -> String? {
        guard pid > 1, pid != getpid() else { return "Refusing to stop this process" }
        if kill(pid, force ? SIGKILL : SIGTERM) == 0 { return nil }
        return errno == EPERM ? "Permission denied (owned by another user)" : String(cString: strerror(errno))
    }

    static func isAlive(_ pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }
}
