import Cocoa

/// A borderless, always-on-top window that visually occludes a strip of the
/// menu bar. It sits above the system status-bar window level so any status
/// items positioned underneath it (icons dragged there by the user) are
/// covered — they keep running, they're just visually hidden, exactly like
/// putting a running process "in storage" instead of quitting it.
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
        ignoresMouseEvents = true // never intercept clicks; it's a pure visual cover
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        // One above .statusBar so the cover sits directly on top of status
        // items (which live at .statusBar), fully occluding them.
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)

        let effect = NSVisualEffectView()
        effect.material = .menu // matches the live menu bar's own vibrancy/material
        effect.blendingMode = .behindWindow
        effect.state = .active
        contentView = effect
    }

    /// Repositions the cover to sit directly under the given screen frame's
    /// menu bar, spanning `width` points immediately to the left of `rightEdgeX`.
    func reposition(onScreen screen: NSScreen, rightEdgeX: CGFloat, width: CGFloat) {
        let barHeight = screen.frame.maxY - screen.visibleFrame.maxY == 0
            ? NSStatusBar.system.thickness
            : max(NSStatusBar.system.thickness, screen.frame.maxY - screen.visibleFrame.maxY)
        let topY = screen.frame.maxY
        let frame = NSRect(
            x: rightEdgeX - width,
            y: topY - barHeight,
            width: width,
            height: barHeight
        )
        setFrame(frame, display: true)
    }
}
