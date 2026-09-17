import AppKit
import Observation

/// Owns the Ellipsis icon and the restriction, and keeps the restriction in
/// step with the hidden sets.
@MainActor
@Observable
final class MenuBarManager {
    let sets: HiddenSets
    let state: AppState

    private let restriction: MenuBarRestriction
    private let icon = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var launchObserver: Task<Void, Never>?

    init(restriction: MenuBarRestriction, sets: HiddenSets, state: AppState) {
        self.restriction = restriction
        self.sets = sets
        self.state = state

        icon.autosaveName = "ellipsis.icon"
        icon.button?.title = "…"

        applyCurrentState()

        // A newly launched app is not in the allow-list snapshot, so it would hide.
        let launches = NSWorkspace.shared.notificationCenter
            .notifications(named: NSWorkspace.didLaunchApplicationNotification)
        launchObserver = Task { [weak self] in
            for await _ in launches.map({ _ in () }) {
                guard let self, restriction.isActive else { continue }
                applyCurrentState()
            }
        }
    }

    func applyCurrentState() {
        let hidden = sets.identifiersToHide(isAlwaysHiddenEnabled: state.isAlwaysHiddenEnabled)
        if hidden.isEmpty {
            restriction.release()
        } else {
            restriction.apply(hiddenBundleIdentifiers: hidden)
        }
        icon.button?.title = sets.isHiddenSetShown ? "‹" : "…"
    }

    func release() {
        launchObserver?.cancel()
        restriction.release()
    }
}
