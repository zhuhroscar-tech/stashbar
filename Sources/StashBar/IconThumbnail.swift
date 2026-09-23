import Cocoa
import ScreenCaptureKit

/// Captures a live thumbnail of a stashed status icon so the drawer panel
/// can show what's actually inside it (not just a generic placeholder).
/// Falls back to a generic glyph if Screen Recording permission hasn't been
/// granted or the capture fails for any reason — never crashes, never blocks
/// the panel from opening.
enum IconThumbnail {
    static func capture(item: StashItem) async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let scWindow = content.windows.first(where: { $0.windowID == item.id }) else {
                debugLog("IconThumbnail: window id \(item.id) not found among \(content.windows.count) SCWindows")
                return nil
            }
            let filter = SCContentFilter(desktopIndependentWindow: scWindow)
            let config = SCStreamConfiguration()
            let scale: CGFloat = 2 // retina-sharp thumbnail
            config.width = max(1, Int(scWindow.frame.width * scale))
            config.height = max(1, Int(scWindow.frame.height * scale))
            config.showsCursor = false

            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            let image = NSImage(cgImage: cgImage, size: NSSize(width: scWindow.frame.width, height: scWindow.frame.height))
            if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: "/tmp/stashbar_last_thumbnail.png"))
            }
            return image
        } catch {
            debugLog("IconThumbnail: capture threw \(error)")
            return nil
        }
    }
}
