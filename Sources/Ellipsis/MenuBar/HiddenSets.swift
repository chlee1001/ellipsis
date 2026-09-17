import Foundation
import Observation

/// The two sets of bundle identifiers Ellipsis hides, and whether the hidden
/// set is currently shown. Persisted in `UserDefaults`.
@MainActor
@Observable
final class HiddenSets {
    enum Key {
        static let hidden = "hiddenBundleIdentifiers"
        static let alwaysHidden = "alwaysHiddenBundleIdentifiers"
        static let isHiddenSetShown = "isHiddenSetShown"
    }

    private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
        hidden = Set(store.stringArray(forKey: Key.hidden) ?? [])
        alwaysHidden = Set(store.stringArray(forKey: Key.alwaysHidden) ?? [])
        isHiddenSetShown = store.bool(forKey: Key.isHiddenSetShown)
    }

    var hidden: Set<String> {
        didSet { store.set(hidden.sorted(), forKey: Key.hidden) }
    }

    var alwaysHidden: Set<String> {
        didSet { store.set(alwaysHidden.sorted(), forKey: Key.alwaysHidden) }
    }

    var isHiddenSetShown: Bool {
        didSet { store.set(isHiddenSetShown, forKey: Key.isHiddenSetShown) }
    }

    /// The bundle identifiers a restriction must hide right now.
    /// Empty means no restriction is necessary.
    func identifiersToHide(isAlwaysHiddenEnabled: Bool) -> Set<String> {
        var result = isHiddenSetShown ? [] : hidden
        if isAlwaysHiddenEnabled {
            result.formUnion(alwaysHidden)
        }
        return result
    }
}
