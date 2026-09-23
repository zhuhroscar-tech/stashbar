import Cocoa

/// Private CGEventField used by macOS's window server to record which
/// window a synthetic event targets. Not exposed by CGEventField's public
/// cases; raw value confirmed against Ice's own MenuBarItemManager.swift
/// (github.com/jordanbaird/Ice), which uses the same undocumented key.
private extension CGEventField {
    static let windowID = CGEventField(rawValue: 0x33)!
}

/// Forwards a synthetic left-click to a stashed status icon at its real
/// screen position. This mirrors the open-source Ice menu-bar manager's
/// technique (MenuBarItemManager.click(item:) at
/// github.com/jordanbaird/Ice) rather than a plain `postToPid`, because a
/// plain post is not enough on this macOS version: the click only actually
/// activates the target status-bar button when the event also carries that
/// item's windowID in dedicated CGEvent fields, and the real cursor is
/// warped there first (some NSStatusBarButton hit-testing keys off the
/// pointer's live position, not just the event's recorded coordinates).
///
/// Requires Accessibility permission (posting synthetic events targeted at
/// another process is gated by it). If not granted, this silently no-ops;
/// DrawerPanel shows a hint to grant it instead of forwarding blind clicks
/// that would do nothing.
enum ClickForwarder {
    static func forward(to item: StashItem) {
        guard AccessibilityPermission.isTrusted() else {
            debugLog("ClickForwarder: not trusted, skipping")
            return
        }
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            debugLog("ClickForwarder: no event source")
            return
        }

        let point = CGPoint(x: item.frame.midX, y: item.frame.midY)
        let savedCursor = CGEvent(source: nil)?.location ?? point
        debugLog("ClickForwarder: posting to pid=\(item.ownerPID) windowID=\(item.id) at \(point)")

        guard
            let mouseDown = menuBarItemEvent(type: .leftMouseDown, location: point, item: item, source: source),
            let mouseUp = menuBarItemEvent(type: .leftMouseUp, location: point, item: item, source: source)
        else {
            debugLog("ClickForwarder: event creation failed")
            return
        }

        // Move the real cursor there first -- some menu-bar-item buttons
        // (AppKit's NSStatusBarButton included) key their highlight/hit-test
        // state off the actual pointer location, not just the event's
        // recorded coordinates.
        CGWarpMouseCursorPosition(point)
        CGAssociateMouseAndMouseCursorPosition(0)

        mouseDown.post(tap: .cghidEventTap)
        usleep(30_000)
        mouseUp.post(tap: .cghidEventTap)
        usleep(30_000)

        CGAssociateMouseAndMouseCursorPosition(1)
        CGWarpMouseCursorPosition(savedCursor)
    }

    /// Builds one leg (down or up) of the synthetic click. Internal (not
    /// private) so tests can verify the exact event fields set — this is
    /// the single most failure-prone part of the whole mechanism (a wrong
    /// windowID/PID silently no-ops instead of erroring), so it is worth
    /// covering directly rather than only through a live end-to-end click.
    static func menuBarItemEvent(
        type: CGEventType,
        location: CGPoint,
        item: StashItem,
        source: CGEventSource
    ) -> CGEvent? {
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location, mouseButton: .left) else {
            return nil
        }

        let windowID = Int64(item.id)
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(item.ownerPID))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: windowID)
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: windowID)
        event.setIntegerValueField(.windowID, value: windowID)
        if type == .leftMouseDown || type == .leftMouseUp {
            event.setIntegerValueField(.mouseEventClickState, value: 1)
        }
        return event
    }
}
