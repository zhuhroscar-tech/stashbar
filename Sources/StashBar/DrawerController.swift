import Cocoa
import ServiceManagement

/// Core controller: owns the drawer's status item, the occluding cover
/// window, and the open/close state machine.
///
/// Mental model (matches the "Minecraft chest" the user described):
///   - Closed drawer  -> cover window is shown, hiding whatever the user
///                       dragged left of the drawer icon. Those apps keep
///                       running; they're just stashed out of sight.
///   - Open drawer    -> cover window is pulled away, revealing the real
///                       menu bar icons in their real positions so the user
///                       can click them directly (Cloudflare, etc.).
final class DrawerController {

    private var statusItem: NSStatusItem!
    private let cover = CoverWindow()
    private var isOpen = false
    private var autoCloseTimer: Timer?
    private var outsideClickMonitor: Any?

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
        updateCover()
    }

    func stop() {
        cover.orderOut(nil)
        removeOutsideClickMonitor()
        autoCloseTimer?.invalidate()
    }

    // MARK: - Interaction

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { toggle(); return }
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
        isOpen = true
        cover.orderOut(nil)
        if let button = statusItem.button { configureIcon(button, open: true) }
        installOutsideClickMonitor()
        scheduleAutoClose()
    }

    private func close() {
        isOpen = false
        autoCloseTimer?.invalidate()
        removeOutsideClickMonitor()
        if let button = statusItem.button { configureIcon(button, open: false) }
        updateCover()
    }

    private func scheduleAutoClose() {
        autoCloseTimer?.invalidate()
        let delay = Preferences.autoCloseSeconds
        guard delay > 0 else { return }
        autoCloseTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.close()
        }
    }

    /// While the drawer is open, any click elsewhere (using the now-visible
    /// real icon counts as "elsewhere" too — that's fine, the user is done
    /// once they've clicked it) re-covers the stash automatically, like a
    /// chest lid falling shut once you've taken what you needed.
    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp]) { [weak self] _ in
            self?.close()
        }
    }

    private func removeOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    // MARK: - Cover geometry

    private func updateCover() {
        guard !isOpen,
              let button = statusItem.button,
              let window = button.window,
              let screen = window.screen ?? NSScreen.main
        else { return }

        let rightEdgeX = window.frame.minX
        cover.reposition(onScreen: screen, rightEdgeX: rightEdgeX, width: Preferences.hiddenWidth)
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

        let widthLabel = NSMenuItem(title: "Stash zone width: \(Int(Preferences.hiddenWidth)) pt", action: nil, keyEquivalent: "")
        widthLabel.isEnabled = false
        menu.addItem(widthLabel)

        menu.addItem(NSMenuItem(title: "Widen Stash Zone", action: #selector(widen), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Narrow Stash Zone", action: #selector(narrow), keyEquivalent: ""))
        menu.addItem(.separator())

        let autoCloseItem = NSMenuItem(
            title: Preferences.autoCloseSeconds > 0
                ? "Auto-close after \(Int(Preferences.autoCloseSeconds))s"
                : "Auto-close: Off",
            action: #selector(cycleAutoClose),
            keyEquivalent: ""
        )
        menu.addItem(autoCloseItem)

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.state = Preferences.launchAtLogin ? .on : .off
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "How it works…", action: #selector(showHelp), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit StashBar", action: #selector(quit), keyEquivalent: "q"))

        for entry in menu.items { entry.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // one-shot: don't let it swallow future left-clicks
    }

    @objc private func widen() {
        Preferences.hiddenWidth += Preferences.step
        updateCover()
    }

    @objc private func narrow() {
        Preferences.hiddenWidth -= Preferences.step
        updateCover()
    }

    @objc private func cycleAutoClose() {
        let options: [TimeInterval] = [0, 4, 6, 10, 20]
        let current = Preferences.autoCloseSeconds
        let next = options.first(where: { $0 > current }) ?? options[0]
        Preferences.autoCloseSeconds = next
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

    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "How StashBar works"
        alert.informativeText = """
        StashBar covers a strip of the menu bar just left of its drawer icon (🗃), \
        hiding whatever lives there — the apps behind those icons keep running.

        To stash an icon: hold ⌘ and drag it left of the drawer icon.
        To use a stashed icon: click the drawer to open it, then click the \
        real icon like normal. The drawer closes again automatically.

        Right-click the drawer icon any time to resize the stash zone or \
        change settings.
        """
        alert.alertStyle = .informational
        alert.runModal()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
