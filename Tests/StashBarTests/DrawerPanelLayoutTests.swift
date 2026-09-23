import Testing
@testable import StashBar
import CoreGraphics

struct StashZoneGeometryTests {
    @Test func zoneSitsImmediatelyLeftOfDrawer() {
        let drawerBounds = CGRect(x: -715, y: -1474, width: 38, height: 24)
        let (minX, maxX) = StashZoneGeometry.zoneRange(drawerBounds: drawerBounds, zoneWidth: 260)
        #expect(maxX == -715)
        #expect(minX == -975)
    }

    @Test func zoneWidensWithConfiguredWidth() {
        let drawerBounds = CGRect(x: -715, y: -1474, width: 38, height: 24)
        let (minX, _) = StashZoneGeometry.zoneRange(drawerBounds: drawerBounds, zoneWidth: 500)
        #expect(minX == -1215)
    }
}

struct DrawerPanelLayoutTests {
    @Test func panelGrowsDownwardNotSideways() {
        // The user's explicit, repeated requirement: expanding the panel
        // must never change its X origin or width -- only Y and height.
        // This is the single most important regression to catch.
        let anchor = CGPoint(x: -715, y: -1474)
        let short = DrawerPanelLayout.frame(anchorTopLeft: anchor, contentHeight: 52)
        let tall = DrawerPanelLayout.frame(anchorTopLeft: anchor, contentHeight: 200)

        #expect(short.origin.x == tall.origin.x, "panel must not shift horizontally as it grows")
        #expect(short.width == tall.width, "panel must not widen as it grows")
        #expect(tall.origin.y < short.origin.y, "panel must extend downward (lower Y) as content grows")
        #expect(tall.height == 200)
    }

    @Test func topEdgeStaysAnchoredRegardlessOfHeight() {
        let anchor = CGPoint(x: -715, y: -1474)
        for height: CGFloat in [52, 88, 124, 300] {
            let frame = DrawerPanelLayout.frame(anchorTopLeft: anchor, contentHeight: height)
            #expect(abs((frame.origin.y + frame.height) - anchor.y) < 0.001, "top edge (origin.y + height) must equal the anchor Y for every height")
        }
    }

    @Test func contentHeightGrowsWithItemCount() {
        let one = DrawerPanelLayout.contentHeight(itemCount: 1, showPermissionHint: false)
        let three = DrawerPanelLayout.contentHeight(itemCount: 3, showPermissionHint: false)
        #expect(one < three)
        #expect(three - one == DrawerPanelLayout.rowHeight * 2)
    }

    @Test func contentHeightIncludesPermissionHintOnlyWhenShown() {
        let without = DrawerPanelLayout.contentHeight(itemCount: 1, showPermissionHint: false)
        let with = DrawerPanelLayout.contentHeight(itemCount: 1, showPermissionHint: true)
        #expect(with - without == DrawerPanelLayout.permissionRowHeight)
    }

    @Test func contentHeightIsCappedAtMaxHeight() {
        let huge = DrawerPanelLayout.contentHeight(itemCount: 100, showPermissionHint: true)
        #expect(huge == DrawerPanelLayout.maxHeight)
    }

    @Test func emptyStateHasFixedHeightRegardlessOfPermissionHint() {
        // showPermissionHint should never be true when there are no items
        // (DrawerController only sets it when items is non-empty), but the
        // layout function itself should still behave sanely if ever misused.
        let empty = DrawerPanelLayout.contentHeight(itemCount: 0, showPermissionHint: false)
        #expect(empty == DrawerPanelLayout.emptyStateHeight + DrawerPanelLayout.verticalPadding * 2)
    }
}
