import Foundation
import Observation

/// Settings other than the hidden sets. Every property reads and writes one
/// `UserDefaults` key so a Settings view and the menu bar code see the same value.
@MainActor
@Observable
final class AppState {
    enum Key {
        static let isAlwaysHiddenEnabled = "isAlwaysHiddenEnabled"
        static let rehideOnTimeout = "rehideOnTimeout"
        static let rehideOnClickOutside = "rehideOnClickOutside"
        static let rehideOnFocusChange = "rehideOnFocusChange"
        static let rehideTimeout = "rehideTimeout"
        static let clockZoneWidth = "clockZoneWidth"
        static let hidesAppsLeftOfIcon = "hidesAppsLeftOfIcon"
    }

    static let defaults: [String: Any] = [
        Key.isAlwaysHiddenEnabled: true,
        Key.rehideOnTimeout: true,
        Key.rehideOnClickOutside: true,
        Key.rehideOnFocusChange: false,
        Key.rehideTimeout: 15.0,
        Key.clockZoneWidth: 300.0,
        Key.hidesAppsLeftOfIcon: false,
    ]

    static func registerDefaults(in store: UserDefaults = .standard) {
        store.register(defaults: defaults)
    }

    private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
        isAlwaysHiddenEnabled = store.bool(forKey: Key.isAlwaysHiddenEnabled)
        rehideOnTimeout = store.bool(forKey: Key.rehideOnTimeout)
        rehideOnClickOutside = store.bool(forKey: Key.rehideOnClickOutside)
        rehideOnFocusChange = store.bool(forKey: Key.rehideOnFocusChange)
        rehideTimeout = store.double(forKey: Key.rehideTimeout)
        clockZoneWidth = store.double(forKey: Key.clockZoneWidth)
        hidesAppsLeftOfIcon = store.bool(forKey: Key.hidesAppsLeftOfIcon)
    }

    /// Reads every value from the store again, after an import wrote to it.
    func reload() {
        isAlwaysHiddenEnabled = store.bool(forKey: Key.isAlwaysHiddenEnabled)
        rehideOnTimeout = store.bool(forKey: Key.rehideOnTimeout)
        rehideOnClickOutside = store.bool(forKey: Key.rehideOnClickOutside)
        rehideOnFocusChange = store.bool(forKey: Key.rehideOnFocusChange)
        rehideTimeout = store.double(forKey: Key.rehideTimeout)
        clockZoneWidth = store.double(forKey: Key.clockZoneWidth)
        hidesAppsLeftOfIcon = store.bool(forKey: Key.hidesAppsLeftOfIcon)
    }

    var isAlwaysHiddenEnabled: Bool {
        didSet { store.set(isAlwaysHiddenEnabled, forKey: Key.isAlwaysHiddenEnabled) }
    }
    var rehideOnTimeout: Bool {
        didSet { store.set(rehideOnTimeout, forKey: Key.rehideOnTimeout) }
    }
    var rehideOnClickOutside: Bool {
        didSet { store.set(rehideOnClickOutside, forKey: Key.rehideOnClickOutside) }
    }
    var rehideOnFocusChange: Bool {
        didSet { store.set(rehideOnFocusChange, forKey: Key.rehideOnFocusChange) }
    }
    /// Seconds. 1–300.
    var rehideTimeout: Double {
        didSet { store.set(rehideTimeout, forKey: Key.rehideTimeout) }
    }
    /// Points from the right edge of the menu bar. The restriction lifts
    /// while the pointer is in this zone, so that a clock click opens
    /// Notification Center. See `ClockZone`.
    var clockZoneWidth: Double {
        didSet { store.set(clockZoneWidth, forKey: Key.clockZoneWidth) }
    }
    /// The Ellipsis icon is the divider: apps left of it are the hidden set.
    /// Needs the Accessibility permission. See `IconDivider`.
    var hidesAppsLeftOfIcon: Bool {
        didSet { store.set(hidesAppsLeftOfIcon, forKey: Key.hidesAppsLeftOfIcon) }
    }
}
