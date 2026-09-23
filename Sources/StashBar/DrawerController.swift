import Cocoa
import ServiceManagement

/// Core controller. Owns:
///   - the drawer's own status item (the 🗃 icon),
///   - the CoverWindow painted over the stash zone (so any icon the user
///     cmd-drags into that zone is visually hidden, though still fully
///     running -- covering is purely visual, nothing is moved or killed),
///   - the DrawerPanel that expands DOWNWARD from the icon on click,
///     listing every currently-stashed icon with a live thumbnail,
///   - click forwarding, so picking a row in the panel actually operates
///     the real app behind it.
final class DrawerController {

    private var statusItem: NSStatusItem!
    private let cover = CoverWindow()
    private let panel = DrawerPanel()
    private var isOpen = false
    private var outsideClickMonitor: Any?
    private var thumbnails: [CGWindowID: NSImage] = [:]
    private var refreshTimer: Timer?

    private let closedSymbol = "tray.fill"
    private let openSymbol = "tray.and.arrow.up.fill"

    func start() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "StashBar.Drawer"
        if let button = item.button {
            configureIcon(button, open: false)
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item

        panel.onSelect = { [weak self] item in
            self?.select(item)
        }

        updateCover()

        // Periodically re-check the stash zone even while closed, so the
        // cover always reflects reality (e.g. an app relaunched and its
        // icon reappeared in a slightly different spot).
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateCover()
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        cover.orderOut(nil)
        panel.dismiss()
        removeOutsideClickMonitor()
    }

    // MARK: - Interaction

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { toggle(); return }
        debugLog("handleClick event.type=\(event.type.rawValue)")
        if event.type == .rightMouseUp {
            showMenu()
        } else {
            toggle()
        }
    }

    private func toggle() {
        isOpen ? close() : open()
    }

    private func open() {
        guard
            let button = statusItem.button,
            let window = button.window,
            let screen = window.screen ?? NSScreen.main
        else { return }

        isOpen = true
        configureIcon(button, open: true)

        let anchorTopLeft = CGPoint(x: window.frame.minX, y: window.frame.minY)
        let items = currentStashItems(screen: screen)
        debugLog("open() button.window.frame=\(window.frame) button.window.screen=\(String(describing: window.screen)) NSScreen.main=\(String(describing: NSScreen.main)) items=\(items.count) mouseLocation=\(NSEvent.mouseLocation)")
        panel.update(items: items, thumbnails: thumbnails, anchorTopLeft: anchorTopLeft)
        panel.present()
        installOutsideClickMonitor()

        // Thumbnails load asynchronously and refresh the panel in place
        // (avoids blocking the click with a synchronous screen capture).
        Task { [weak self] in
            guard let self else { return }
            for stashItem in items where self.thumbnails[stashItem.id] == nil {
                debugLog("requesting thumbnail for \(stashItem.ownerName) id=\(stashItem.id)")
                if let image = await IconThumbnail.capture(item: stashItem) {
                    debugLog("thumbnail captured for \(stashItem.ownerName): size=\(image.size)")
                    self.thumbnails[stashItem.id] = image
                    await MainActor.run {
                        self.panel.update(items: items, thumbnails: self.thumbnails, anchorTopLeft: anchorTopLeft)
                    }
                } else {
                    debugLog("thumbnail capture FAILED/nil for \(stashItem.ownerName)")
                }
            }
        }
    }

    private func close() {
        debugLog("close() called, isOpen was \(isOpen)")
        isOpen = false
        removeOutsideClickMonitor()
        if let button = statusItem.button { configureIcon(button, open: false) }
        panel.dismiss()
    }

    private func select(_ item: StashItem) {
        debugLog("select() forwarding click to \(item.ownerName)")
        ClickForwarder.forward(to: item)
        close()
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            debugLog("outsideClickMonitor fired, event location=\(event.locationInWindow) window=\(String(describing: event.window))")
            self?.close()
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    // MARK: - Stash zone geometry

    /// Finds our own drawer button's window in the CGWindowList (the same
    /// coordinate space StashScanner reads from) instead of using
    /// NSWindow.frame, which is in AppKit's flipped (bottom-left-origin)
    /// space and is NOT directly comparable to CGWindowList's
    /// top-left-origin bounds. Mixing the two was the bug that made the
    /// stash zone scan always come back empty.
    private func ownDrawerWindowBounds() -> CGRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        let targetID = CGWindowID(window.windowNumber)
        let opts: CGWindowListOption = [.optionOnScreenOnly]
        guard let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: AnyObject]] else { return nil }
        guard
            let entry = list.first(where: { ($0[kCGWindowNumber as String] as? CGWindowID) == targetID }),
            let boundsDict = entry[kCGWindowBounds as String] as? [String: CGFloat]
        else { return nil }
        return CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )
    }

    private func currentStashItems(screen: NSScreen) -> [StashItem] {
        guard let bounds = ownDrawerWindowBounds() else { return [] }
        let (zoneMinX, zoneMaxX) = StashZoneGeometry.zoneRange(drawerBounds: bounds, zoneWidth: Preferences.zoneWidth)
        return StashScanner.scan(
            zoneMinX: zoneMinX,
            zoneMaxX: zoneMaxX,
            y: bounds.minY,
            excludingOwnerPID: ProcessInfo.processInfo.processIdentifier
        )
    }

    private func updateCover() {
        guard
            !isOpen,
            let button = statusItem.button,
            let window = button.window,
            let screen = window.screen ?? NSScreen.main
        else { return }

        let rightEdgeX = window.frame.minX
        cover.reposition(onScreen: screen, rightEdgeX: rightEdgeX, width: Preferences.zoneWidth)
        cover.orderFrontRegardless()
    }

    // MARK: - Icon

    private func configureIcon(_ button: NSStatusBarButton, open: Bool) {
        let name = open ? openSymbol : closedSymbol
        let description = open ? "Stash drawer (open)" : "Stash drawer (closed)"
        if let image = NSImage(systemSymbolName: name, accessibilityDescription: description) {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = open ? "📤" : "🗃"
        }
    }

    // MARK: - Menu

    private func showMenu() {
        let menu = NSMenu()

        let widthLabel = NSMenuItem(title: "Stash zone width: \(Int(Preferences.zoneWidth)) pt", action: nil, keyEquivalent: "")
        widthLabel.isEnabled = false
        menu.addItem(widthLabel)
        menu.addItem(NSMenuItem(title: "Widen Stash Zone", action: #selector(widen), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Narrow Stash Zone", action: #selector(narrow), keyEquivalent: ""))
        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.state = Preferences.launchAtLogin ? .on : .off
        menu.addItem(loginItem)

        let accessItem = NSMenuItem(title: "Grant Accessibility Access…", action: #selector(requestAccessibility), keyEquivalent: "")
        accessItem.isHidden = AccessibilityPermission.isTrusted()
        menu.addItem(accessItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "How it works…", action: #selector(showHelp), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit StashBar", action: #selector(quit), keyEquivalent: "q"))

        for entry in menu.items { entry.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func widen() {
        Preferences.zoneWidth += Preferences.zoneStep
        updateCover()
    }

    @objc private func narrow() {
        Preferences.zoneWidth -= Preferences.zoneStep
        updateCover()
    }

    @objc private func toggleLaunchAtLogin() {
        let newValue = !Preferences.launchAtLogin
        do {
            if newValue {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            Preferences.launchAtLogin = newValue
        } catch {
            NSLog("StashBar: launch-at-login toggle failed: \(error)")
        }
    }

    @objc private func requestAccessibility() {
        AccessibilityPermission.ensureRequested()
    }

    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "How StashBar works"
        alert.informativeText = """
        The strip of menu bar just left of the drawer icon (🗃) is your stash \
        zone. Hold ⌘ and drag any status icon there, the same way macOS \
        already lets you reorder menu-bar icons -- StashBar visually covers \
        it. The app behind it keeps running.

        Click the drawer to drop down a list of everything currently \
        stashed, with a live icon for each. Click an entry to operate it \
        directly -- StashBar clicks it for you at its real position, then \
        the drawer closes again.

        Clicking a stashed icon for you requires Accessibility access \
        (right-click the drawer to grant it).
        """
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
