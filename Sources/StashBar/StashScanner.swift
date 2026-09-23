import Cocoa

/// Scans the live menu bar (via the public CGWindowList API — no private
/// APIs, no window repositioning) for other apps' status icons that
/// currently fall inside the stash zone: the strip immediately left of
/// StashBar's own drawer icon.
///
/// Menu-bar status items live at CGWindowLevel 25 ("kCGStatusWindowLevel").
/// We read their real on-screen bounds, which already share the same
/// coordinate space CGEventPost uses, so no conversion is needed when we
/// later forward a synthetic click.
enum StashScanner {
    static let statusItemLayer = 25

    static func scan(zoneMinX: CGFloat, zoneMaxX: CGFloat, y: CGFloat, excludingOwnerPID: pid_t) -> [StashItem] {
        let opts: CGWindowListOption = [.optionOnScreenOnly]
        guard let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: AnyObject]] else {
            return []
        }
        return filter(windowList: list, zoneMinX: zoneMinX, zoneMaxX: zoneMaxX, y: y, excludingOwnerPID: excludingOwnerPID)
    }

    /// The actual filtering/parsing logic, separated from the live
    /// CGWindowList call so it can be unit tested with fabricated window
    /// dictionaries instead of requiring a real screen and real other apps.
    static func filter(
        windowList: [[String: AnyObject]],
        zoneMinX: CGFloat,
        zoneMaxX: CGFloat,
        y: CGFloat,
        excludingOwnerPID: pid_t
    ) -> [StashItem] {
        var results: [StashItem] = []
        for entry in windowList {
            guard
                let layer = entry[kCGWindowLayer as String] as? Int,
                layer == statusItemLayer,
                let boundsDict = entry[kCGWindowBounds as String] as? [String: CGFloat],
                let windowID = entry[kCGWindowNumber as String] as? CGWindowID,
                let ownerPID = entry[kCGWindowOwnerPID as String] as? pid_t,
                ownerPID != excludingOwnerPID,
                let ownerName = entry[kCGWindowOwnerName as String] as? String
            else { continue }

            let x = boundsDict["X"] ?? 0
            let itemY = boundsDict["Y"] ?? 0
            // Only consider items on the same menu bar row (within a
            // reasonable vertical tolerance) so multi-monitor setups don't
            // cross-contaminate.
            guard abs(itemY - y) < 6 else { continue }
            guard x >= zoneMinX && x < zoneMaxX else { continue }

            let frame = CGRect(
                x: x,
                y: itemY,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )
            results.append(StashItem(id: windowID, ownerName: ownerName, ownerPID: ownerPID, frame: frame))
        }

        // Left-to-right in screen order for a stable, predictable panel layout.
        return results.sorted { $0.frame.minX < $1.frame.minX }
    }
}
