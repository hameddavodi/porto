import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let welcomeShownKey = "porto.welcomeShown.v1"

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !UserDefaults.standard.bool(forKey: welcomeShownKey) else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.showWelcomeAlert()
        }
    }

    private func showWelcomeAlert() {
        let alert = NSAlert()
        alert.messageText = "Welcome to Porto"
        alert.informativeText = """
        Porto lives in your menu bar and shows the dev servers, Docker containers, \
        and other services listening on your machine — with one-click stop.

        Add Porto to your Login Items so it starts automatically each time you log in?
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Add to Login Items")
        alert.addButton(withTitle: "Not Now")
        alert.addButton(withTitle: "Don't Ask Again")

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            // Mark as shown only when registration completes (success OR pending-approval).
            // On hard failure, leave the flag unset so user can retry next launch.
            if registerLoginItem() {
                UserDefaults.standard.set(true, forKey: welcomeShownKey)
            }
        case .alertThirdButtonReturn:
            UserDefaults.standard.set(true, forKey: welcomeShownKey)
        default:
            break  // Not Now: ask again next launch
        }
    }

    /// Returns true if registration reached a terminal success state
    /// (.enabled OR .requiresApproval — both mean "we did our part").
    /// Returns false on hard failure so the welcome flag stays unset.
    @discardableResult
    private func registerLoginItem() -> Bool {
        let service = SMAppService.mainApp
        do {
            if service.status != .enabled {
                try service.register()
            }
        } catch {
            showAlert("Couldn't add to Login Items",
                      friendlySMError(error),
                      style: .warning)
            return false
        }

        // Re-read status: register() can succeed but leave the service awaiting user approval.
        switch service.status {
        case .enabled:
            showAlert("Porto added to Login Items",
                      "You can disable this in System Settings → General → Login Items.",
                      style: .informational)
            return true
        case .requiresApproval:
            showAlert("Approval required",
                      "Porto is registered but needs your approval. Open System Settings → General → Login Items and enable Porto.",
                      style: .warning)
            return true
        case .notRegistered:
            showAlert("Couldn't add to Login Items",
                      "Registration didn't complete. Try again later.",
                      style: .warning)
            return false
        case .notFound:
            showAlert("Couldn't add to Login Items",
                      "Login service is not available for this build of Porto.",
                      style: .warning)
            return false
        @unknown default:
            return false
        }
    }

    private func friendlySMError(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == "SMAppServiceErrorDomain" {
            switch ns.code {
            case 1: return "Permission denied. Move Porto to /Applications and try again."
            case 2: return "Service definition not found."
            case 108: return "This build of Porto isn't signed for login-item registration. Rebuild from /Applications or sign with a Developer ID."
            default: return "SMAppService error \(ns.code): \(ns.localizedDescription)"
            }
        }
        return error.localizedDescription
    }

    private func showAlert(_ title: String, _ message: String, style: NSAlert.Style) {
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.alertStyle = style
        a.runModal()
    }
}
