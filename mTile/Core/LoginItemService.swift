import Foundation
import ServiceManagement

/// Manages launch-at-login registration for the main app.
final class LoginItemService {
    static let shared = LoginItemService()

    private init() {}

    /// Best-effort synchronization used on startup.
    func synchronize(enabled shouldEnable: Bool) {
        if isEnabled == shouldEnable { return }
        _ = setEnabled(shouldEnable)
    }

    var isEnabled: Bool {
        guard #available(macOS 13.0, *) else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    func setEnabled(_ enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *) else { return false }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            print("mTile: failed to update launch-at-login state to \(enabled): \(error)")
            return false
        }
    }
}
