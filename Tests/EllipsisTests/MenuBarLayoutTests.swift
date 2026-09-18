import Foundation
import Testing
@testable import Ellipsis
import EllipsisCore

struct MenuBarLayoutTests {
    @Test func clockOffsetIsMeasuredFromTheRightEdge() {
        let layout = MenuBarLayout(displays: [
            MenuBarLayout.Display(frame: CGRect(x: -1000, y: 0, width: 1000, height: 30), items: [
                MenuBarLayout.Item(bundleIdentifier: "a", frame: CGRect(x: -300, y: 0, width: 40, height: 30)),
            ]),
            MenuBarLayout.Display(frame: CGRect(x: 0, y: 0, width: 2000, height: 30), items: [
                MenuBarLayout.Item(systemIdentifier: MenuBarLayout.clockIdentifier, frame: CGRect(x: 1900, y: 0, width: 80, height: 30)),
            ]),
        ])
        #expect(layout.clockOffset == 100)
    }

    @Test func noClockMeansNoOffset() {
        let layout = MenuBarLayout(displays: [
            MenuBarLayout.Display(frame: CGRect(x: 0, y: 0, width: 2000, height: 30), items: [
                MenuBarLayout.Item(bundleIdentifier: "a", frame: CGRect(x: 1900, y: 0, width: 80, height: 30)),
            ]),
        ])
        #expect(layout.clockOffset == nil)
    }
}
