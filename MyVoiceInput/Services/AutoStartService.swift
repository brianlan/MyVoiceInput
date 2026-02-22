import Foundation
import ServiceManagement

/// Service for managing app auto-start at login using SMAppService (macOS 13+)
final class AutoStartService {
    
    /// Returns whether the app is currently set to launch at login
    var isEnabled: Bool {
        return SMAppService.mainApp.status == .enabled
    }
    
    /// Enables launching the app at login
    /// - Returns: true if successful, false if registration failed
    @discardableResult
    func enable() -> Bool {
        do {
            try SMAppService.mainApp.register()
            return true
        } catch {
            print("AutoStartService: Failed to enable auto-start: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Disables launching the app at login
    /// - Returns: true if successful, false if unregistration failed
    @discardableResult
    func disable() -> Bool {
        do {
            try SMAppService.mainApp.unregister()
            return true
        } catch {
            print("AutoStartService: Failed to disable auto-start: \(error.localizedDescription)")
            return false
        }
    }
}
