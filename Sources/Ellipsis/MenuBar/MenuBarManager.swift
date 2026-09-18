import AppKit
import EllipsisCore
import Observation

/// Owns the Ellipsis icon and the restriction, and keeps the restriction in
/// step with the hidden sets.
@MainActor
@Observable
final class MenuBarManager {
    let sets: HiddenSets
    let state: AppState

    private let restriction: MenuBarRestriction
    private let rehide: RehideMonitor
    private let updater: Updater
    private let permission: AccessibilityPermission
    private var floatingBar: FloatingBar?
    /// The app whose item a bar click is opening. While set, and while the
    /// set is shown, the restriction hides every other app so that item fits.
    private var clickThroughTarget: String?
    private var clickThrough: Task<Void, Never>?
    private var barPlacement: Task<Void, Never>?
    private let openSettingsHandler: () -> Void
    private let icon = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var launchObserver: Task<Void, Never>?
    private var pointerMonitor: Any?
    private var clockHoverRestore: Task<Void, Never>?
    private var isPointerInClockZone = false

    private static let hiddenImage = ellipsisImage()
    private static let shownImage = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Hide items")?
        .withSymbolConfiguration(.init(pointSize: 15, weight: .bold))

    /// Three 4-point dots, like the Ice control item. SF Symbol `ellipsis`
    /// is too small at menu bar sizes.
    private static func ellipsisImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { _ in
            NSColor.black.setFill()
            for x in stride(from: 2.0, through: 14.0, by: 6.0) {
                NSBezierPath(ovalIn: NSRect(x: x, y: 8, width: 4, height: 4)).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Show hidden items"
        return image
    }

    init(
        restriction: MenuBarRestriction,
        sets: HiddenSets,
        state: AppState,
        permission: AccessibilityPermission,
        updater: Updater,
        openSettings: @escaping () -> Void
    ) {
        self.restriction = restriction
        self.sets = sets
        self.state = state
        self.permission = permission
        self.updater = updater
        self.openSettingsHandler = openSettings
        self.rehide = RehideMonitor(state: state, sets: sets)
        rehide.panelFrame = { [weak self] in self?.floatingBar?.frame }

        icon.autosaveName = "ellipsis.icon"
        if let button = icon.button {
            button.target = self
            button.action = #selector(iconClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        applyCurrentState()
        observeChanges()
        installClockHover()

        // A newly launched app is not in the allow-list snapshot, so it would hide.
        launchObserver = Task { [weak self] in
            for await _ in NSWorkspace.runningApplicationChanges() {
                guard let self, restriction.isActive else { continue }
                self.applyCurrentState()
            }
        }
    }

    /// The icon's window frame in screen coordinates, for the divider.
    var iconFrame: NSRect? { icon.button?.window?.frame }

    // MARK: Show and hide

    /// A normal click toggles the hidden set. An Option click toggles both sets.
    func toggle(includingAlwaysHidden: Bool) {
        let isShown = includingAlwaysHidden ? sets.isAlwaysHiddenSetShown : sets.isHiddenSetShown
        if isShown {
            hide()
        } else {
            show(includingAlwaysHidden: includingAlwaysHidden)
        }
    }

    func show(includingAlwaysHidden: Bool) {
        sets.show(includingAlwaysHidden: includingAlwaysHidden)
    }

    func hide() {
        sets.hide()
    }

    func applyCurrentState() {
        let inBar = state.hiddenItemsPlacement == .floatingBar
        if !sets.isHiddenSetShown {
            clickThroughTarget = nil
        }
        let hidden: Set<String>
        if let target = clickThroughTarget {
            let running = NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
            hidden = Set(running).subtracting([target, Bundle.main.bundleIdentifier ?? ""])
        } else if inBar {
            // The bar shows the set; the menu bar keeps hiding it.
            hidden = sets.hidden.union(state.isAlwaysHiddenEnabled ? sets.alwaysHidden : [])
        } else {
            hidden = sets.identifiersToHide(isAlwaysHiddenEnabled: state.isAlwaysHiddenEnabled)
        }
        if hidden.isEmpty {
            restriction.release()
        } else {
            restriction.apply(hiddenBundleIdentifiers: hidden)
        }
        icon.button?.image = sets.isHiddenSetShown ? Self.shownImage : Self.hiddenImage
        updateFloatingBar(inBar: inBar)

        // Arm once per show, not on every reapply, so the timeout is not reset
        // by unrelated changes such as the clock hover.
        if sets.isHiddenSetShown {
            if !rehide.isArmed {
                rehide.arm()
            }
        } else {
            rehide.disarm()
        }
    }

    func release() {
        rehide.disarm()
        clickThrough?.cancel()
        barPlacement?.cancel()
        floatingBar?.hide()
        launchObserver?.cancel()
        clockHoverRestore?.cancel()
        if let pointerMonitor {
            NSEvent.removeMonitor(pointerMonitor)
        }
        restriction.release()
    }

    /// Reapplies the restriction whenever a set or a related setting changes,
    /// from any caller. `onChange` fires once per registration, before the
    /// write lands, so it hops to the next run-loop turn and re-registers.
    private func observeChanges() {
        withObservationTracking {
            _ = sets.hidden
            _ = sets.alwaysHidden
            _ = sets.isHiddenSetShown
            _ = sets.isAlwaysHiddenSetShown
            _ = state.isAlwaysHiddenEnabled
            _ = state.hiddenItemsPlacement
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.applyCurrentState()
                self.observeChanges()
            }
        }
    }

    // MARK: The floating bar

    private func updateFloatingBar(inBar: Bool) {
        guard inBar, sets.isHiddenSetShown, clickThroughTarget == nil else {
            floatingBar?.hide()
            return
        }
        if floatingBar == nil {
            floatingBar = FloatingBar { [weak self] id in
                self?.barClicked(id)
            }
        }
        var shown = sets.hidden
        if sets.isAlwaysHiddenSetShown {
            shown.formUnion(sets.alwaysHidden)
        }
        let screen = icon.button?.window?.screen ?? NSScreen.main ?? NSScreen.screens[0]
        floatingBar?.show(
            apps: FloatingBar.apps(for: shown),
            hint: permission.isTrusted ? nil : "with the Accessibility permission, one click opens its menu bar item",
            iconFrame: iconFrame,
            screen: screen
        )
        // The icon can move once MenuBarAgent lays out the new restriction;
        // the bar follows it.
        barPlacement?.cancel()
        barPlacement = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self, let bar = floatingBar, bar.isVisible else { return }
            bar.place(iconFrame: iconFrame, screen: icon.button?.window?.screen ?? screen)
        }
    }

    /// Click-through, spec F8. A restriction that allows only this app and
    /// Ellipsis makes its item fit, whatever the display. With the
    /// Accessibility permission the item is then pressed and the normal
    /// restriction returns once its menu closes. Without it the item stays
    /// for the user to click, until a rehide or the icon.
    private func barClicked(_ id: String) {
        clickThrough?.cancel()
        clickThroughTarget = id
        applyCurrentState()
        guard permission.isTrusted else { return }
        clickThrough = Task { [weak self] in
            // MenuBarAgent lays out after the restriction; the divider's delay.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            let pressed = await Task.detached(priority: .userInitiated) {
                MenuBarLayout.read()?.displays.lazy
                    .flatMap(\.items)
                    .first { $0.bundleIdentifier == id }?
                    .element?.press() ?? false
            }.value
            guard !Task.isCancelled, let self else { return }
            if pressed {
                // Let the menu open, then wait for it to close.
                try? await Task.sleep(for: .milliseconds(300))
                while !Task.isCancelled, RehidePolicy.isMenuOpen(MenuBarGeometry.openMenuFrames(), menuBar: .current) {
                    try? await Task.sleep(for: .milliseconds(300))
                }
                guard !Task.isCancelled else { return }
            }
            self.clickThroughTarget = nil
            self.hide()
            self.applyCurrentState()
        }
    }

    // MARK: Clock hover

    /// Notification Center does not open from a clock click while a
    /// restriction is active, and MenuBarAgent decides that at mouse-down.
    /// So the restriction lifts while the pointer is in the trailing zone of
    /// the menu bar and returns shortly after it leaves. `ClockZone` sizes
    /// the zone.
    private func installClockHover() {
        pointerMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            let point = NSEvent.mouseLocation
            Task { @MainActor in
                self?.pointerMoved(to: point)
            }
        }
    }

    private func pointerMoved(to point: NSPoint) {
        let inZone = MenuBarGeometry.current.clockZoneContains(point, width: state.clockZoneWidth)
        guard inZone != isPointerInClockZone else { return }
        isPointerInClockZone = inZone
        clockHoverRestore?.cancel()
        if inZone {
            restriction.release()
        } else {
            clockHoverRestore = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                self?.applyCurrentState()
            }
        }
    }

    // MARK: Icon clicks

    @objc private func iconClicked() {
        // On macOS 27 the event that reaches the action carries no modifier
        // flags, so read the keyboard state directly.
        let flags = NSEvent.modifierFlags
        let isRightClick = NSApp.currentEvent?.type == .rightMouseUp
        if isRightClick || flags.contains(.control) {
            showMenu()
        } else {
            toggle(includingAlwaysHidden: flags.contains(.option))
        }
    }

    /// A status item with a `menu` opens it on every click, so the menu is
    /// attached only for the duration of one click.
    private func showMenu() {
        let menu = NSMenu()

        let alwaysHidden = NSMenuItem(
            title: "Show always-hidden items",
            action: #selector(toggleAlwaysHiddenShown),
            keyEquivalent: ""
        )
        alwaysHidden.target = self
        alwaysHidden.state = sets.isAlwaysHiddenSetShown ? .on : .off
        alwaysHidden.isEnabled = state.isAlwaysHiddenEnabled
        menu.addItem(alwaysHidden)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let update = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates), keyEquivalent: "")
        update.target = self
        update.isEnabled = updater.canCheckForUpdates
        menu.addItem(update)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Ellipsis", action: #selector(NSApplication.terminate), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        icon.menu = menu
        icon.button?.performClick(nil)
        icon.menu = nil
    }

    @objc private func toggleAlwaysHiddenShown() {
        show(includingAlwaysHidden: !sets.isAlwaysHiddenSetShown)
    }

    @objc private func openSettings() {
        openSettingsHandler()
    }

    @objc private func checkForUpdates() {
        updater.checkForUpdates()
    }
}
