import Cocoa

/// A single row inside the drawer panel: an icon thumbnail plus the owning
/// app's name. Clicking anywhere on the row forwards a click to the real
/// icon and closes the panel.
final class StashRowView: NSView {
    private let onActivate: () -> Void
    private let imageView = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let background = NSView()

    private static let rowHeight: CGFloat = 36
    private static let iconSize: CGFloat = 22

    init(item: StashItem, thumbnail: NSImage?, onActivate: @escaping () -> Void) {
        self.onActivate = onActivate
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: Self.rowHeight).isActive = true

        background.translatesAutoresizingMaskIntoConstraints = false
        background.wantsLayer = true
        background.layer?.cornerRadius = 6
        background.layer?.backgroundColor = NSColor.clear.cgColor
        addSubview(background)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyUpOrDown
        if let thumbnail {
            imageView.image = thumbnail
        } else {
            imageView.image = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: item.ownerName)
            imageView.contentTintColor = .secondaryLabelColor
        }
        addSubview(imageView)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.stringValue = item.ownerName
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.lineBreakMode = .byTruncatingTail
        addSubview(label)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            background.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            background.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            background.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),

            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: Self.iconSize),
            imageView.heightAnchor.constraint(equalToConstant: Self.iconSize),

            label.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        let tracking = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(tracking)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func mouseEntered(with event: NSEvent) {
        background.layer?.backgroundColor = NSColor.selectedContentBackgroundColor.withAlphaComponent(0.18).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        background.layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func mouseUp(with event: NSEvent) {
        debugLog("StashRowView.mouseUp fired, frame=\(frame)")
        onActivate()
    }
}
