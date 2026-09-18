import EllipsisCore
import Foundation
import Testing

/// Spec F8. A short status item region (the wide fixture frontmost, the
/// stand-in for a notch) collapses shown items behind macOS's own «. In
/// bar mode the restriction stays, nothing collapses, and a panel below
/// the menu bar lists the hidden apps.
@Suite(.serialized, .enabled(if: Guest.isConfigured))
struct FloatingBarTests {
    let guest = Guest()
    let bar: [String: Guest.Setting] = [
        "hiddenItemsPlacement": .string("floatingBar"),
        "hiddenBundleIdentifiers": .strings(Fixture.all),
    ]

    init() throws {
        try guest.startFixtures()
    }

    private func launchInBarMode(_ extra: [String: Guest.Setting] = [:]) throws {
        try guest.launchEllipsis(bar.merging(extra) { $1 })
        try guest.waitUntil("A hides") { try !guest.appItems().contains(Fixture.a) }
    }

    private func showBar() throws {
        try guest.clickIcon()
        try guest.waitUntil("the bar opens") { try guest.barButtons() != nil }
    }

    /// `open` launches the app on the first call and activates it on the
    /// next, so it repeats until the app is frontmost.
    private func bringWideFixtureToFront() throws {
        try guest.waitUntil("the wide fixture is frontmost", interval: 1) {
            try guest.launch(Fixture.wideName)
            Thread.sleep(forTimeInterval: 0.5)
            return try guest.frontmostApp() == Fixture.wideName
        }
        try guest.waitUntilSettled()
    }

    @Test func aShortRegionCollapsesItemsInMenuBarMode() throws {
        try guest.launchEllipsis(["hiddenBundleIdentifiers": .strings(Fixture.all)])
        try guest.waitUntil("the set hides") { try guest.appItems().isDisjoint(with: Fixture.all) }
        try bringWideFixtureToFront()
        #expect(try !guest.hasOverflowButton())
        try guest.clickIcon()
        try guest.waitUntil("macOS collapses what does not fit") { try guest.hasOverflowButton() }
    }

    @Test func showOpensTheBarAndKeepsTheMenuBarHidden() throws {
        try launchInBarMode()
        try bringWideFixtureToFront()
        try showBar()
        #expect(try guest.barButtons()?.map(\.name) == ["FixtureA", "FixtureB", "FixtureC"])
        try guest.expectStable("the items stay hidden") { try guest.appItems().isDisjoint(with: Fixture.all) }
        #expect(try !guest.hasOverflowButton())
        #expect(try guest.setting("isHiddenSetShown") == "1")

        let icon = try #require(try guest.iconFrame())
        let frame = try #require(try guest.barFrame())
        #expect(abs(frame.maxX - icon.maxX) <= 4, "the bar hangs from the icon's right edge")
        #expect(frame.minY > icon.maxY && frame.minY < icon.maxY + 12, "the bar sits just below the menu bar")

        try guest.clickIcon()
        try guest.waitUntil("the bar closes") { try guest.barButtons() == nil }
    }

    @Test func optionShowAddsTheAlwaysHiddenSet() throws {
        try launchInBarMode([
            "hiddenBundleIdentifiers": .strings([Fixture.a]),
            "alwaysHiddenBundleIdentifiers": .strings([Fixture.b]),
        ])
        try guest.clickIcon()
        try guest.waitUntil("the bar shows A") { try guest.barButtons()?.map(\.name) == ["FixtureA"] }
        try guest.clickIcon()
        try guest.waitUntil("the bar closes") { try guest.barButtons() == nil }
        try guest.clickIcon(option: true)
        try guest.waitUntil("the bar shows A and B") { try guest.barButtons()?.map(\.name) == ["FixtureA", "FixtureB"] }
    }

    @Test func rehideConditionsCloseTheBar() throws {
        try launchInBarMode(["rehideOnTimeout": .bool(true), "rehideTimeout": .double(2)])
        try showBar()
        try guest.waitUntil("the timeout closes the bar", timeout: 5) { try guest.barButtons() == nil }

        try launchInBarMode(["rehideOnClickOutside": .bool(true)])
        try showBar()
        let frame = try #require(try guest.barFrame())
        try guest.probe("click \(Int(frame.midX)) \(Int(frame.maxY + 40))")
        try guest.waitUntil("a click outside closes the bar") { try guest.barButtons() == nil }

        try launchInBarMode(["rehideOnFocusChange": .bool(true)])
        try showBar()
        try guest.run("open -a TextEdit")
        try guest.waitUntil("a focus change closes the bar") { try guest.barButtons() == nil }
        try guest.run("pkill -x TextEdit || true")
    }

    @Test func clickInTheBarIsNotOutside() throws {
        try launchInBarMode(["rehideOnClickOutside": .bool(true)])
        try showBar()
        let frame = try #require(try guest.barFrame())
        try guest.probe("click \(Int(frame.midX)) \(Int(frame.minY + 4))")  // the bar's top padding, no button
        try guest.expectStable("the bar stays") { try guest.barButtons() != nil }
    }

    /// Without the Accessibility permission a click leaves the app's item
    /// alone in the menu bar for the user to click.
    @Test func clickOnAnAppWithoutPermissionShowsThatItemAlone() throws {
        try launchInBarMode()
        try bringWideFixtureToFront()
        try showBar()
        let button = try #require(try guest.barButtons()?.first { $0.name == "FixtureB" })
        try guest.click(button.frame)
        try guest.waitUntil("B appears") { try guest.appItems().contains(Fixture.b) }
        try guest.waitUntil("the bar closes") { try guest.barButtons() == nil }
        try guest.expectStable("A and C stay hidden and B stays") {
            let items = try guest.appItems()
            return items.contains(Fixture.b) && items.isDisjoint(with: [Fixture.a, Fixture.c])
        }
        #expect(try !guest.hasOverflowButton())
        try guest.clickIcon()
        try guest.waitUntil("the icon hides B again") { try !guest.appItems().contains(Fixture.b) }
    }

    /// With the permission a click opens the app's menu; the normal
    /// restriction returns when the menu closes.
    @Test func clickOnAnAppOpensItsMenu() throws {
        try launchInBarMode()
        guard try guest.setting("clockZoneWidth") != "150" else {
            // The measured width means the app holds the permission.
            Issue.record("Ellipsis has no Accessibility grant in this guest; run scripts/vm-test.sh")
            return
        }
        try bringWideFixtureToFront()
        try guest.run("rm -f \(Fixture.markerPath(Fixture.a))")
        try showBar()
        let button = try #require(try guest.barButtons()?.first { $0.name == "FixtureA" })
        try guest.click(button.frame)
        var menu: CGRect?
        try guest.waitUntil("A's menu opens") {
            menu = try guest.openMenus().first { $0.minY < 42 }
            return menu != nil
        }
        let menuFrame = try #require(menu)
        try guest.click(CGRect(x: menuFrame.minX, y: menuFrame.minY + 6, width: menuFrame.width, height: 20))  // "Mark"
        try guest.waitUntil("Mark runs") { try !guest.run("ls \(Fixture.markerPath(Fixture.a)) 2>/dev/null || true").isEmpty }
        try guest.waitUntil("the normal restriction returns") {
            try guest.appItems().isDisjoint(with: Fixture.all) && guest.setting("isHiddenSetShown") == "0"
        }
    }
}
