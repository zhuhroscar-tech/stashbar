import Cocoa

enum DrawerPanelLayout {
    static let width: CGFloat = 260
    static let maxHeight: CGFloat = 420
    static let verticalPadding: CGFloat = 8
    static let rowHeight: CGFloat = 36
    static let permissionRowHeight: CGFloat = 48
    static let emptyStateHeight: CGFloat = 60

    /// Pure content-height calculation, factored out of DrawerPanel so it
    /// can be unit tested without instantiating any real NSPanel/NSView.
    static func contentHeight(itemCount: Int, showPermissionHint: Bool) -> CGFloat {
        let rowsHeight = itemCount == 0 ? emptyStateHeight : CGFloat(itemCount) * rowHeight
        let permissionExtra: CGFloat = showPermissionHint ? permissionRowHeight : 0
        return min(rowsHeight + verticalPadding * 2 + permissionExtra, maxHeight)
    }

    /// Pure frame calculation: the panel's TOP-LEFT corner is anchored to
    /// `anchorTopLeft` and it grows straight DOWN as content height grows,
    /// never sideways -- this is what satisfies the "expand downward, not
    /// horizontal" requirement, and is worth testing in isolation from any
    /// live window so a future change can't silently regress it back to a
    /// sideways-growing panel.
    static func frame(anchorTopLeft: CGPoint, contentHeight: CGFloat) -> CGRect {
        CGRect(
            x: anchorTopLeft.x - width + 32, // right-align roughly under the drawer icon
            y: anchorTopLeft.y - contentHeight,
            width: width,
            height: contentHeight
        )
    }
}

/// The panel that drops down from the drawer icon, showing every stashed
/// status icon as a clickable row. Anchored so its TOP edge stays fixed
/// just under the menu bar and its height grows downward as more icons are
/// stashed — never sideways, so it never competes for the same scarce
/// horizontal space that caused the problem in the first place.
final class DrawerPanel: NSPanel {

    private let stack = NSStackView()
    private let scrollView = NSScrollView()
    private let emptyLabel = NSTextField(labelWithString: "Nothing stashed yet")
    private let permissionRow: NSView
    private let permissionLabel = NSTextField(wrappingLabelWithString: "")

    private typealias Layout = DrawerPanelLayout
    private static let width = Layout.width
    private static let maxHeight = Layout.maxHeight
    private static let verticalPadding = Layout.verticalPadding
    private static let rowHeight = Layout.rowHeight
    private static let permissionRowHeight = Layout.permissionRowHeight

    var onSelect: ((StashItem) -> Void)?

    init() {
        let row = NSView()
        self.permissionRow = row

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 10),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovable = false

        let container = NSVisualEffectView()
        container.material = .popover
        container.state = .active
        container.wantsLayer = true
        container.layer?.cornerRadius = 12
        container.layer?.masksToBounds = true
        contentView = container

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        emptyLabel.font = .systemFont(ofSize: 12)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false

        // Built once, reused across update() calls -- never re-parented or
        // given fresh constraints per call, so nothing accumulates.
        permissionRow.translatesAutoresizingMaskIntoConstraints = false
        permissionLabel.font = .systemFont(ofSize: 11)
        permissionLabel.textColor = .secondaryLabelColor
        permissionLabel.alignment = .center
        permissionLabel.stringValue = "Grant Accessibility access (System Settings) so StashBar can click stashed icons for you."
        permissionLabel.translatesAutoresizingMaskIntoConstraints = false
        permissionLabel.preferredMaxLayoutWidth = Self.width - 32
        permissionRow.addSubview(permissionLabel)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.documentView = stack

        container.addSubview(scrollView)
        container.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: Self.verticalPadding),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -Self.verticalPadding),

            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            permissionRow.widthAnchor.constraint(equalToConstant: Self.width),
            permissionRow.heightAnchor.constraint(equalToConstant: Self.permissionRowHeight),
            permissionLabel.leadingAnchor.constraint(equalTo: permissionRow.leadingAnchor, constant: 16),
            permissionLabel.trailingAnchor.constraint(equalTo: permissionRow.trailingAnchor, constant: -16),
            permissionLabel.centerYAnchor.constraint(equalTo: permissionRow.centerYAnchor),
        ])
    }

    /// Rebuilds the row list and resizes so the panel's TOP stays anchored
    /// under `anchorTopLeft` while its height grows downward to fit content.
    func update(items: [StashItem], thumbnails: [CGWindowID: NSImage], anchorTopLeft: CGPoint) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        emptyLabel.isHidden = !items.isEmpty
        let showPermissionHint = !items.isEmpty && !AccessibilityPermission.isTrusted()

        for item in items {
            let row = StashRowView(item: item, thumbnail: thumbnails[item.id]) { [weak self] in
                self?.onSelect?(item)
            }
            row.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
            stack.addArrangedSubview(row)
        }

        if showPermissionHint {
            stack.addArrangedSubview(permissionRow)
        } else if permissionRow.superview != nil {
            permissionRow.removeFromSuperview()
        }

        let contentHeight = Layout.contentHeight(itemCount: items.count, showPermissionHint: showPermissionHint)
        let frame = Layout.frame(anchorTopLeft: anchorTopLeft, contentHeight: contentHeight)
        setFrame(frame, display: true)
    }

    func present() {
        orderFrontRegardless()
    }

    func dismiss() {
        orderOut(nil)
    }

    override var canBecomeKey: Bool { true }
}
