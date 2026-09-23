import Foundation

/// Small persisted-settings wrapper.
enum Preferences {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let zoneWidth = "StashBar.zoneWidth"
        static let launchAtLogin = "StashBar.launchAtLogin"
        static let autoRecoverSeconds = "StashBar.autoRecoverSeconds"
    }

    static let minZoneWidth: CGFloat = 60
    static let maxZoneWidth: CGFloat = 1200
    static let zoneStep: CGFloat = 32

    /// Width (points) of the stash zone immediately left of the drawer icon.
    /// Any other app's status icon that ends up inside this x-range (the
    /// user cmd-drags it there, the same native gesture macOS already uses
    /// to reorder menu-bar icons) is treated as "stashed": visually covered
    /// and listed in the drawer panel.
    static var zoneWidth: CGFloat {
        get {
            let stored = defaults.double(forKey: Key.zoneWidth)
            return stored == 0 ? 260 : CGFloat(stored)
        }
        set {
            defaults.set(Double(min(max(newValue, minZoneWidth), maxZoneWidth)), forKey: Key.zoneWidth)
        }
    }

    static var launchAtLogin: Bool {
        get { defaults.bool(forKey: Key.launchAtLogin) }
        set { defaults.set(newValue, forKey: Key.launchAtLogin) }
    }

    /// Seconds after a forwarded click before the stash zone is covered
    /// again automatically (also re-covers immediately on any other click).
    static var autoRecoverSeconds: Double {
        get {
            if defaults.object(forKey: Key.autoRecoverSeconds) == nil { return 1.2 }
            return defaults.double(forKey: Key.autoRecoverSeconds)
        }
        set { defaults.set(newValue, forKey: Key.autoRecoverSeconds) }
    }
}
