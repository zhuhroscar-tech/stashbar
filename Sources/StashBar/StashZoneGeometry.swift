import CoreGraphics

/// Pure geometry helpers for the stash zone, kept separate from
/// DrawerController (which touches NSStatusItem/NSWindow) so the math
/// itself can be unit tested without any live AppKit window.
enum StashZoneGeometry {
    /// Given the drawer button's own on-screen bounds (CGWindowList space)
    /// and the configured zone width, returns the horizontal range that
    /// counts as "inside the stash zone" -- immediately to the left of the
    /// drawer icon.
    static func zoneRange(drawerBounds: CGRect, zoneWidth: CGFloat) -> (minX: CGFloat, maxX: CGFloat) {
        let maxX = drawerBounds.minX
        let minX = maxX - zoneWidth
        return (minX, maxX)
    }
}
