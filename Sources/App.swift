import SwiftUI
import AppKit

@main
struct PortoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var monitor = ServiceMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuView(monitor: monitor)
        } label: {
            MenuBarLabel()
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    private static let icon: NSImage? = {
        guard let img = NSImage(named: "MenuBarIcon") else { return nil }
        img.isTemplate = true
        return img
    }()

    var body: some View {
        if let icon = Self.icon {
            Image(nsImage: icon)
        } else {
            Image(systemName: "network")
        }
    }
}
