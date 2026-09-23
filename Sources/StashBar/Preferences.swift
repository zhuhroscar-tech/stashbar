import Foundation

/// Small persisted-settings wrapper. Kept separate so the drawer logic
/// doesn't scatter UserDefaults keys everywhere.
enum Preferences {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let hiddenWidth = "StashBar.hiddenWidth"
        static let launchAtLogin = "StashBar.launchAtLogin"
        static let autoCloseSeconds = "StashBar.autoCloseSeconds"
    }

    static let minWidth: CGFloat = 60
    static let maxWidth: CGFloat = 1200
    static let step: CGFloat = 32

    /// Width (in points) of the "hidden zone" immediately left of the
    /// separator icon. Icons the user cmd-drags into this zone get
    /// visually covered when the drawer is closed.
    static var hiddenWidth: CGFloat {
        get {
            let stored = defaults.double(forKey: Key.hiddenWidth)
            return stored == 0 ? 220 : CGFloat(stored)
        }
        set {
            let clamped = min(max(newValue, minWidth), maxWidth)
            defaults.set(Double(clamped), forKey: Key.hiddenWidth)
        }
    }

    static var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }

    /// Seconds the drawer stays open before auto re-closing. 0 = never auto-close.
    static var autoCloseSeconds: Double {
        get {
            if defaults.object(forKey: Key.autoCloseSeconds) == nil { return 6 }
            return defaults.double(forKey: Key.autoCloseSeconds)
        }
        set { defaults.set(newValue, forKey: Key.autoCloseSeconds) }
    }
}
