import Foundation

enum PortScanner {
    static func scan() -> [Service] {
        let out = runShell("/usr/sbin/lsof", args: ["-nP", "-iTCP", "-sTCP:LISTEN", "-F", "pcn"])
        return parse(out)
    }

    static func parse(_ text: String) -> [Service] {
        var services: [Service] = []
        var pid: Int32 = 0
        var name = ""
        var seen = Set<String>()
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let first = rawLine.first else { continue }
            let value = String(rawLine.dropFirst())
            switch first {
            case "p":
                pid = Int32(value) ?? 0
                name = ""
            case "c":
                name = value
            case "n":
                guard let port = extractPort(value) else { continue }
                let address: String
                if value.hasPrefix("*:") || value.hasPrefix("[::]:") || value.hasPrefix("0.0.0.0:") {
                    address = "0.0.0.0"
                } else {
                    address = "localhost"
                }
                let key = "\(pid)-\(port)"
                if seen.contains(key) { continue }
                seen.insert(key)
                services.append(Service(
                    id: "proc-\(pid)-\(port)",
                    kind: .process,
                    name: name.isEmpty ? "?" : name,
                    port: port,
                    pid: pid,
                    containerId: nil,
                    address: address
                ))
            default:
                break
            }
        }
        return services
    }

    private static func extractPort(_ s: String) -> Int? {
        guard let colonIdx = s.lastIndex(of: ":") else { return nil }
        let portPart = s[s.index(after: colonIdx)...]
        return Int(portPart)
    }
}
