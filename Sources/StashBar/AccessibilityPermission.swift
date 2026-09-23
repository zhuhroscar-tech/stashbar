import Cocoa
import ApplicationServices

/// StashBar needs to post synthetic clicks at a stashed icon's real screen
/// position (to actually trigger it) and that requires the Accessibility
/// permission, same as every other menu-bar manager (Bartender, Ice, etc.).
/// This only prompts once; if denied, forwarded clicks simply won't fire and
/// we tell the user why instead of failing silently.
enum AccessibilityPermission {
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system's own "grant Accessibility access" prompt if not
    /// already trusted. Safe to call on every launch — it only prompts once
    /// per denial/grant cycle.
    static func ensureRequested() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
