import AppKit

/// Phase 0 spike: hide menu bar items on macOS 27 with the assessment-mode
/// restriction from the private MenuBarClientCore framework.
///
/// Click the icon to toggle. The bundle identifiers to hide come from the
/// `hiddenBundleIdentifiers` user default:
///
///     defaults write to.haryan.Ellipsis hiddenBundleIdentifiers -array com.example.a com.example.b
///
/// Run the bundle from /Applications. MenuBarAgent cannot match an app that
/// runs from anywhere else against the allow-list, so its own icon would hide.
@MainActor
final class Spike: NSObject {
    private let icon = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var assertion: AnyObject?

    /// MenuBarAgent takes system items as integer codes. 0–6 match the public
    /// `AEMenuBarItem` constants in order; 8 is Control Center. Codes past the
    /// enum are ignored, so a generous range keeps every allowable item visible.
    private static let allSystemItems = (0...40).map { NSNumber(value: $0) }

    override init() {
        super.init()
        icon.autosaveName = "ellipsis.icon"
        icon.button?.title = "‹"
        icon.button?.target = self
        icon.button?.action = #selector(toggle)
    }

    @objc private func toggle() {
        if assertion != nil {
            release()
        } else {
            hide()
        }
    }

    private func hide() {
        let hidden = Set(UserDefaults.standard.stringArray(forKey: "hiddenBundleIdentifiers") ?? [])
        let running = NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        let allowed = Array(Set(running).subtracting(hidden))

        guard
            let configClass = NSClassFromString("MBAssessmentModeConfiguration") as? NSObject.Type,
            let assertionClass = NSClassFromString("MBAssessmentModeAssertion") as? NSObject.Type
        else {
            NSLog("MBAssessmentMode classes not found")
            return
        }

        let config = (configClass as AnyObject).perform(NSSelectorFromString("alloc"))?.takeUnretainedValue()
            .perform(NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:"),
                     with: Self.allSystemItems as NSArray, with: allowed as NSArray)?
            .takeUnretainedValue()
        let assertion = assertionClass.init()
        let completion: @convention(block) (Any?) -> Void = { error in
            NSLog("restriction active, error=%@", String(describing: error))
        }
        _ = assertion.perform(NSSelectorFromString("activateWithConfiguration:completionHandler:"),
                              with: config, with: completion)
        self.assertion = assertion
        icon.button?.title = "…"
    }

    private func release() {
        _ = assertion?.perform(NSSelectorFromString("invalidate"))
        assertion = nil
        icon.button?.title = "‹"
    }
}

guard dlopen("/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore", RTLD_NOW) != nil else {
    fatalError("MenuBarClientCore failed to load: \(String(cString: dlerror()))")
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let spike = Spike()
app.run()
