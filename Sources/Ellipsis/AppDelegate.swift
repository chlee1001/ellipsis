import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var menuBar: MenuBarManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppState.registerDefaults()
        let restriction: MenuBarRestriction
        do {
            restriction = try MenuBarRestriction()
        } catch {
            Self.quit(with: error)
            return
        }
        menuBar = MenuBarManager(
            restriction: restriction,
            sets: HiddenSets(),
            state: AppState()
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBar?.release()
    }

    private static func quit(with error: Error) {
        let alert = NSAlert()
        alert.messageText = "Ellipsis cannot run on this version of macOS"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Quit")
        NSApp.activate()
        alert.runModal()
        NSApp.terminate(nil)
    }
}
