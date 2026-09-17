import AppKit

enum MenuBarRestrictionError: LocalizedError {
    case frameworkNotLoaded(String)
    case classesNotFound

    var errorDescription: String? {
        switch self {
        case .frameworkNotLoaded(let reason):
            "MenuBarClientCore did not load: \(reason)"
        case .classesNotFound:
            "The MBAssessmentMode classes do not exist in this version of macOS."
        }
    }
}

/// One assessment-mode assertion against `MenuBarAgent`, through the private
/// `MenuBarClientCore` framework. See `docs/spec.md`, "How it hides".
@MainActor
final class MenuBarRestriction {
    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore"

    /// MenuBarAgent takes system items as integer codes. 0–6 match the public
    /// `AEMenuBarItem` constants in order; 8 is Control Center. Codes past the
    /// enum are ignored, so a generous range keeps every allowable item visible.
    private static let allSystemItems = (0...40).map { NSNumber(value: $0) }

    private let configurationClass: NSObject.Type
    private let assertionClass: NSObject.Type
    private var assertion: NSObject?

    var isActive: Bool { assertion != nil }

    init() throws {
        guard dlopen(Self.frameworkPath, RTLD_NOW) != nil else {
            throw MenuBarRestrictionError.frameworkNotLoaded(String(cString: dlerror()))
        }
        guard
            let configurationClass = NSClassFromString("MBAssessmentModeConfiguration") as? NSObject.Type,
            let assertionClass = NSClassFromString("MBAssessmentModeAssertion") as? NSObject.Type
        else {
            throw MenuBarRestrictionError.classesNotFound
        }
        self.configurationClass = configurationClass
        self.assertionClass = assertionClass
    }

    /// Hides the given apps and shows every other running app and every system
    /// item. Replaces any assertion held before. The allow-list is a snapshot of
    /// the running apps, so call this again when an app launches.
    func apply(hiddenBundleIdentifiers hidden: Set<String>) {
        let running = NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        let allowed = Set(running).subtracting(hidden).sorted()

        let configuration = (configurationClass as AnyObject)
            .perform(NSSelectorFromString("alloc"))?.takeUnretainedValue()
            .perform(NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:"),
                     with: Self.allSystemItems as NSArray, with: allowed as NSArray)?
            .takeUnretainedValue()
        let assertion = assertionClass.init()
        let completion: @convention(block) (Any?) -> Void = { error in
            if let error {
                NSLog("Ellipsis: restriction failed: %@", String(describing: error))
            }
        }
        _ = assertion.perform(NSSelectorFromString("activateWithConfiguration:completionHandler:"),
                              with: configuration, with: completion)

        // Activate the new one before the old one goes so items do not flash.
        release()
        self.assertion = assertion
    }

    func release() {
        _ = assertion?.perform(NSSelectorFromString("invalidate"))
        assertion = nil
    }
}
