import ApplicationServices
import Testing
@testable import Ellipsis

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

    /// Reads the live menu bar. Needs the Accessibility permission for the
    /// test runner, so it only checks anything when the runner has it.
    @Test func readsTheLiveMenuBar() {
        guard AXIsProcessTrusted() else { return }
        let layout = MenuBarLayout.read()
        #expect(layout != nil)
        guard let layout else { return }
        #expect(!layout.displays.isEmpty)
        for display in layout.displays {
            #expect(display.frame.width > 0)
            #expect(display.items.contains { $0.systemIdentifier == MenuBarLayout.clockIdentifier })
            #expect(display.items.contains { $0.bundleIdentifier != nil })
            for item in display.items {
                #expect(display.frame.contains(item.frame))
            }
        }
        #expect(layout.clockOffset.map { $0 > 0 && $0 < 400 } == true)
    }
}
