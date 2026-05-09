import Foundation

enum ServiceKind: Hashable {
    case process
    case docker
}

struct Service: Identifiable, Hashable {
    let id: String
    let kind: ServiceKind
    let name: String
    let port: Int
    let pid: Int32?
    let containerId: String?
    let address: String
}

enum ServiceCategory: String, CaseIterable, Identifiable {
    case python = "Python"
    case node = "Node"
    case docker = "Docker"
    case other = "Other"
    case system = "System"
    var id: String { rawValue }
}

private let systemProcessNames: Set<String> = [
    "rapportd", "controlcenter", "com.docker.backend",
    "code helper (plugin)", "code helper", "loginwindow",
    "sharingd", "airplayxpchelper", "remoted", "identityservicesd",
    "nsurlsessiond", "cloudd", "bluetoothd", "mdnsresponder",
    "configd", "syslogd", "screensharingd"
]

func category(for s: Service) -> ServiceCategory {
    if s.kind == .docker { return .docker }
    let n = s.name.lowercased()
    if n.contains("python") { return .python }
    if n == "node" || n.hasPrefix("node ") { return .node }
    if systemProcessNames.contains(n) { return .system }
    return .other
}

