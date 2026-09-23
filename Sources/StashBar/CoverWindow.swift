import Cocoa

/// A borderless, always-on-top window that visually occludes the stash
/// zone in the real menu bar. Matches the menu bar's own vibrancy material
/// so it reads as "part of the bar," not a slapped-on rectangle.
///
/// It never intercepts clicks (`ignoresMouseEvents = true`): it's a pure
/// visual cover, so it can never interfere with the icons underneath.
final class CoverWindow: NSWindow {

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        // CGWindowLayer 26 -- one above the status-item layer (25) so it
        // reliably paints over any icon sitting in the stash zone.
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)

        let effect = NSVisualEffectView()
        effect.material = .menu
        effect.blendingMode = .behindWindow
        effect.state = .active
        contentView = effect
    }

    func reposition(onScreen screen: NSScreen, rightEdgeX: CGFloat, width: CGFloat) {
        let barHeight = max(NSStatusBar.system.thickness, screen.frame.maxY - screen.visibleFrame.maxY)
        let topY = screen.frame.maxY
        let frame = NSRect(x: rightEdgeX - width, y: topY - barHeight, width: width, height: barHeight)
        setFrame(frame, display: true)
    }
}
