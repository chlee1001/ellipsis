import SwiftUI

@main
struct EllipsisApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
