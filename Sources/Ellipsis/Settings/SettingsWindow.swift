import AppKit
import SwiftUI

/// The one Settings window. Closing it hides it; `show()` brings it back.
@MainActor
final class SettingsWindow {
    private let window: NSWindow

    init(state: AppState, sets: HiddenSets) {
        let content = SettingsView()
            .environment(state)
            .environment(sets)
        let host = NSHostingController(rootView: content)
        host.sizingOptions = .preferredContentSize
        window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = host
        window.title = "Ellipsis Settings"
        window.isReleasedWhenClosed = false
        window.center()
    }

    func show() {
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }
}
