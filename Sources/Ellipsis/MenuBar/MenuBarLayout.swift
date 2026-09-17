import AppKit
import ApplicationServices

/// The items MenuBarAgent shows on each display, read over Accessibility.
/// Each display has one MenuBarAgent window whose children are the item
/// slots. A slot's child is owned by the app that draws the item, or by
/// MenuBarAgent for a system item. Only MenuBarAgent is asked anything: the
/// owner comes from the element's pid, so an unresponsive app cannot stall
/// the read. Nothing here works without the Accessibility permission.
struct MenuBarLayout: Sendable {
    struct Item: Sendable {
        /// Bundle identifier of the app that owns the item, nil for a system item.
        var bundleIdentifier: String?
        /// `com.apple.menuextra.clock` and the like, nil for an app item.
        var systemIdentifier: String?
        /// Accessibility coordinates: origin at the top left of the primary display.
        var frame: CGRect
    }

    struct Display: Sendable {
        /// The menu bar, in Accessibility coordinates.
        var frame: CGRect
        var items: [Item]
    }

    var displays: [Display]

    static let clockIdentifier = "com.apple.menuextra.clock"

    /// Points from the right edge of the menu bar to the left edge of the
    /// clock. System items sit at the same offset on every display.
    var clockOffset: CGFloat? {
        for display in displays {
            if let clock = display.items.first(where: { $0.systemIdentifier == Self.clockIdentifier }) {
                return display.frame.maxX - clock.frame.minX
            }
        }
        return nil
    }

    /// Nil when MenuBarAgent is not running or refuses, as it does without
    /// the permission. Off the main thread: every read is an IPC.
    nonisolated static func read() -> MenuBarLayout? {
        guard let agent = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").first
        else { return nil }
        let agentPID = agent.processIdentifier
        let app = AXUIElementCreateApplication(agentPID)
        AXUIElementSetMessagingTimeout(app, 1)
        guard let windows: [AXUIElement] = app.attribute(kAXWindowsAttribute) else { return nil }
        let displays = windows.map { window in
            let items = window.children.compactMap { slot -> Item? in
                guard let frame = slot.frame, let owner = slot.children.first else { return nil }
                var pid: pid_t = 0
                AXUIElementGetPid(owner, &pid)
                if pid == agentPID {
                    let identifier: String? = owner.children.first?.attribute(kAXIdentifierAttribute)
                    return Item(systemIdentifier: identifier, frame: frame)
                }
                let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
                return Item(bundleIdentifier: bundleID, frame: frame)
            }
            return Display(frame: window.frame ?? .zero, items: items)
        }
        return MenuBarLayout(displays: displays)
    }
}

private extension AXUIElement {
    func attribute<T>(_ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    var children: [AXUIElement] {
        attribute(kAXChildrenAttribute) ?? []
    }

    var frame: CGRect? {
        guard let position: AXValue = attribute(kAXPositionAttribute),
              let size: AXValue = attribute(kAXSizeAttribute)
        else { return nil }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        AXValueGetValue(position, .cgPoint, &origin)
        AXValueGetValue(size, .cgSize, &extent)
        return CGRect(origin: origin, size: extent)
    }
}
