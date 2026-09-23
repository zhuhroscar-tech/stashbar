import Testing
@testable import StashBar
import CoreGraphics

struct ClickForwarderTests {
    // Raw value cross-checked against Ice's private CGEventField.windowID
    // extension (github.com/jordanbaird/Ice, MenuBarItemManager.swift) --
    // duplicated here (rather than imported) since ClickForwarder's own
    // extension is private to that file.
    private static let windowIDField = CGEventField(rawValue: 0x33)!

    private func makeItem(id: CGWindowID = 42, pid: pid_t = 1234) -> StashItem {
        StashItem(id: id, ownerName: "TestApp", ownerPID: pid, frame: CGRect(x: -800, y: -1474, width: 38, height: 24))
    }

    @Test func eventCarriesTargetProcessID() throws {
        let item = makeItem(pid: 1234)
        let source = try #require(CGEventSource(stateID: .combinedSessionState))
        let event = try #require(ClickForwarder.menuBarItemEvent(type: .leftMouseDown, location: .zero, item: item, source: source))
        #expect(event.getIntegerValueField(.eventTargetUnixProcessID) == 1234)
    }

    @Test func eventCarriesTargetWindowIDInAllThreeFields() throws {
        let item = makeItem(id: 999)
        let source = try #require(CGEventSource(stateID: .combinedSessionState))
        let event = try #require(ClickForwarder.menuBarItemEvent(type: .leftMouseDown, location: .zero, item: item, source: source))
        #expect(event.getIntegerValueField(.mouseEventWindowUnderMousePointer) == 999)
        #expect(event.getIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent) == 999)
        #expect(event.getIntegerValueField(Self.windowIDField) == 999)
    }

    @Test func clickEventsMarkClickState() throws {
        let item = makeItem()
        let source = try #require(CGEventSource(stateID: .combinedSessionState))
        let down = try #require(ClickForwarder.menuBarItemEvent(type: .leftMouseDown, location: .zero, item: item, source: source))
        let up = try #require(ClickForwarder.menuBarItemEvent(type: .leftMouseUp, location: .zero, item: item, source: source))
        #expect(down.getIntegerValueField(.mouseEventClickState) == 1)
        #expect(up.getIntegerValueField(.mouseEventClickState) == 1)
    }

    @Test func eventLocationMatchesRequestedPoint() throws {
        let item = makeItem()
        let source = try #require(CGEventSource(stateID: .combinedSessionState))
        let point = CGPoint(x: -781, y: -1462)
        let event = try #require(ClickForwarder.menuBarItemEvent(type: .leftMouseDown, location: point, item: item, source: source))
        #expect(abs(event.location.x - point.x) < 0.5)
        #expect(abs(event.location.y - point.y) < 0.5)
    }
}
