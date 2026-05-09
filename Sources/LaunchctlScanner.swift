import Foundation

struct LaunchdEntry {
    enum Kind {
        case brew(service: String)   // label "homebrew.mxcl.<name>"
        case userAgent               // any other label in current-user GUI domain
    }
    let label: String
    let pid: Int32?
    let kind: Kind

    var humanDescription: String {
        switch kind {
        case .brew(let name): return "Homebrew service (\(name))"
        case .userAgent:      return "User LaunchAgent (\(label))"
        }
    }

    var stopCommandPreview: String {
        switch kind {
        case .brew(let name): return "brew services stop \(name)"
        case .userAgent:      return "launchctl bootout gui/$(id -u)/\(label)"
        }
    }
}

enum LaunchctlScanner {
    /// Look up a launchd entry whose PID matches the given pid.
    static func find(byPid pid: Int32) -> LaunchdEntry? {
        return scanList { _, runningPid in runningPid == pid }
    }

    /// Look up a launchd entry whose label fuzzy-matches a process name.
    static func find(byNameContaining name: String) -> LaunchdEntry? {
        let needle = name.lowercased()
        return scanList { label, _ in label.lowercased().contains(needle) }
    }

    private static func scanList(matching: (String, Int32?) -> Bool) -> LaunchdEntry? {
        let r = runShellEx("/bin/launchctl", args: ["list"])
        guard r.exitCode == 0 else { return nil }
        // Tab-separated: PID \t Status \t Label
        var first = true
        for raw in r.output.split(separator: "\n", omittingEmptySubsequences: true) {
            if first { first = false; continue }  // skip header row
            let cols = raw.split(separator: "\t", omittingEmptySubsequences: false)
            guard cols.count >= 3 else { continue }
            let pidStr = cols[0].trimmingCharacters(in: .whitespaces)
            let label = cols[2].trimmingCharacters(in: .whitespaces)
            let runningPid: Int32? = (pidStr == "-") ? nil : Int32(pidStr)
            if matching(label, runningPid) {
                return classify(label: label, pid: runningPid)
            }
        }
        return nil
    }

    private static func classify(label: String, pid: Int32?) -> LaunchdEntry {
        let prefix = "homebrew.mxcl."
        if label.hasPrefix(prefix) {
            return LaunchdEntry(label: label, pid: pid,
                                kind: .brew(service: String(label.dropFirst(prefix.count))))
        }
        return LaunchdEntry(label: label, pid: pid, kind: .userAgent)
    }

    private static func brewPath() -> String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Returns (success, message) — message is shown to the user.
    static func executeStop(_ entry: LaunchdEntry) -> (success: Bool, message: String) {
        switch entry.kind {
        case .brew(let serviceName):
            guard let brew = brewPath() else {
                return (false, "Couldn't find the `brew` executable. Is Homebrew installed?")
            }
            let r = runShellEx(brew, args: ["services", "stop", serviceName], timeout: 30.0)
            if r.exitCode == 0 {
                return (true, "Stopped Homebrew service: \(serviceName).")
            }
            return (false, "brew services stop \(serviceName) failed (exit \(r.exitCode)).\n\(r.output)")

        case .userAgent:
            let uid = getuid()
            let r = runShellEx("/bin/launchctl",
                               args: ["bootout", "gui/\(uid)/\(entry.label)"],
                               timeout: 10.0)
            if r.exitCode == 0 {
                return (true, "Unloaded LaunchAgent: \(entry.label).")
            }
            // Some user agents live under "system/" and need root. Offer escalation.
            let script = "do shell script \"/bin/launchctl bootout system/\(entry.label)\" with administrator privileges"
            let r2 = runShellEx("/usr/bin/osascript", args: ["-e", script], timeout: 60.0)
            if r2.exitCode == 0 {
                return (true, "Unloaded system LaunchDaemon: \(entry.label).")
            }
            return (false, "Couldn't unload \(entry.label). It may need to be stopped through its installer (e.g. an app's preferences).")
        }
    }
}
