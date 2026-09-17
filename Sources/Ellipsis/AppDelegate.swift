import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sets: HiddenSets
    private let state: AppState
    private let permission = AccessibilityPermission()
    private var settingsWindow: SettingsWindow?
    private var menuBar: MenuBarManager?
    private var clockZone: ClockZone?

    override init() {
        AppState.registerDefaults()
        sets = HiddenSets()
        state = AppState()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let restriction: MenuBarRestriction
        do {
            restriction = try MenuBarRestriction()
        } catch {
            Self.quit(with: error)
            return
        }
        menuBar = MenuBarManager(restriction: restriction, sets: sets, state: state) { [unowned self] in
            showSettings()
        }
        permission.askAtLaunchIfNeeded()
        clockZone = ClockZone(state: state, permission: permission)
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBar?.release()
    }

    private func showSettings() {
        if settingsWindow == nil, let clockZone {
            settingsWindow = SettingsWindow(state: state, sets: sets, permission: permission, clockZone: clockZone)
        }
        settingsWindow?.show()
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
