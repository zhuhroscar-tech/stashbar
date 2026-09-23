import Testing
@testable import StashBar
import CoreGraphics

struct StashScannerTests {
    private func makeWindowEntry(
        layer: Int,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat = 38,
        height: CGFloat = 24,
        windowNumber: CGWindowID = 1,
        ownerPID: pid_t = 100,
        ownerName: String = "TestApp"
    ) -> [String: AnyObject] {
        [
            kCGWindowLayer as String: layer as AnyObject,
            kCGWindowBounds as String: ["X": x, "Y": y, "Width": width, "Height": height] as AnyObject,
            kCGWindowNumber as String: windowNumber as AnyObject,
            kCGWindowOwnerPID as String: ownerPID as AnyObject,
            kCGWindowOwnerName as String: ownerName as AnyObject,
        ]
    }

    @Test func includesIconInsideZoneOnStatusItemLayer() {
        let entry = makeWindowEntry(layer: StashScanner.statusItemLayer, x: -800, y: -1474)
        let result = StashScanner.filter(windowList: [entry], zoneMinX: -975, zoneMaxX: -715, y: -1474, excludingOwnerPID: 999)
        #expect(result.count == 1)
        #expect(result.first?.ownerName == "TestApp")
    }

    @Test func excludesIconOutsideZoneHorizontally() {
        let entry = makeWindowEntry(layer: StashScanner.statusItemLayer, x: -500, y: -1474)
        let result = StashScanner.filter(windowList: [entry], zoneMinX: -975, zoneMaxX: -715, y: -1474, excludingOwnerPID: 999)
        #expect(result.isEmpty)
    }

    @Test func excludesIconOnWrongLayer() {
        // Anything that isn't the real menu-bar status-item layer (25) must
        // never be picked up, even if its bounds happen to overlap the zone
        // -- e.g. StashBar's own cover window and drawer panel both live at
        // other layers and must never mistakenly "stash" themselves.
        let entry = makeWindowEntry(layer: 101, x: -800, y: -1474)
        let result = StashScanner.filter(windowList: [entry], zoneMinX: -975, zoneMaxX: -715, y: -1474, excludingOwnerPID: 999)
        #expect(result.isEmpty)
    }

    @Test func excludesOwnProcess() {
        let entry = makeWindowEntry(layer: StashScanner.statusItemLayer, x: -800, y: -1474, ownerPID: 42)
        let result = StashScanner.filter(windowList: [entry], zoneMinX: -975, zoneMaxX: -715, y: -1474, excludingOwnerPID: 42)
        #expect(result.isEmpty)
    }

    @Test func excludesIconOnDifferentDisplayRow() {
        // Same X range, but far enough away in Y that it must be a
        // different monitor's menu bar -- must not cross-contaminate.
        let entry = makeWindowEntry(layer: StashScanner.statusItemLayer, x: -800, y: -100)
        let result = StashScanner.filter(windowList: [entry], zoneMinX: -975, zoneMaxX: -715, y: -1474, excludingOwnerPID: 999)
        #expect(result.isEmpty)
    }

    @Test func sortsResultsLeftToRight() {
        let far = makeWindowEntry(layer: StashScanner.statusItemLayer, x: -900, y: -1474, windowNumber: 1, ownerName: "Far")
        let near = makeWindowEntry(layer: StashScanner.statusItemLayer, x: -750, y: -1474, windowNumber: 2, ownerName: "Near")
        let result = StashScanner.filter(windowList: [near, far], zoneMinX: -975, zoneMaxX: -715, y: -1474, excludingOwnerPID: 999)
        #expect(result.map(\.ownerName) == ["Far", "Near"])
    }
}
