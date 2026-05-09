import Foundation

enum DockerScanner {
    private static let candidates = [
        "/usr/local/bin/docker",
        "/opt/homebrew/bin/docker",
        NSHomeDirectory() + "/.docker/bin/docker"
    ]

    static func dockerPath() -> String? {
        candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    static func scan() -> [Service] {
        guard let dpath = dockerPath() else { return [] }
        let out = runShell(dpath, args: ["ps", "--format", "{{json .}}"], timeout: 3.0)
        var services: [Service] = []
        for line in out.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            let id = (obj["ID"] as? String) ?? ""
            let names = (obj["Names"] as? String) ?? "container"
            let portsStr = (obj["Ports"] as? String) ?? ""
            let hostPorts = parseHostPorts(portsStr)
            if hostPorts.isEmpty {
                services.append(Service(
                    id: "docker-\(id)-0",
                    kind: .docker,
                    name: names,
                    port: 0,
                    pid: nil,
                    containerId: id,
                    address: "internal"
                ))
            } else {
                for port in hostPorts {
                    services.append(Service(
                        id: "docker-\(id)-\(port)",
                        kind: .docker,
                        name: names,
                        port: port,
                        pid: nil,
                        containerId: id,
                        address: "localhost"
                    ))
                }
            }
        }
        return services
    }

    // Parses "0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp, 80/tcp"
    static func parseHostPorts(_ s: String) -> [Int] {
        var result = Set<Int>()
        for part in s.split(separator: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard let arrowRange = trimmed.range(of: "->") else { continue }
            let left = trimmed[..<arrowRange.lowerBound]
            guard let colonIdx = left.lastIndex(of: ":") else { continue }
            let portStr = String(left[left.index(after: colonIdx)...])
            if let port = Int(portStr) {
                result.insert(port)
            } else if let dashIdx = portStr.firstIndex(of: "-"),
                      let lo = Int(portStr[..<dashIdx]),
                      let hi = Int(portStr[portStr.index(after: dashIdx)...]),
                      lo <= hi, hi - lo < 200 {
                for p in lo...hi { result.insert(p) }
            }
        }
        return Array(result).sorted()
    }
}
