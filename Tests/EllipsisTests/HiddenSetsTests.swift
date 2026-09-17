import Foundation
import Testing
@testable import Ellipsis

@MainActor
struct HiddenSetsTests {
    private func makeStore() -> UserDefaults {
        let name = "HiddenSetsTests.\(UUID().uuidString)"
        let store = UserDefaults(suiteName: name)!
        store.removePersistentDomain(forName: name)
        return store
    }

    @Test func hiddenStateHidesBothSets() {
        let sets = HiddenSets(store: makeStore())
        sets.hidden = ["a"]
        sets.alwaysHidden = ["b"]
        sets.isHiddenSetShown = false
        #expect(sets.identifiersToHide(isAlwaysHiddenEnabled: true) == ["a", "b"])
    }

    @Test func shownStateHidesOnlyAlwaysHidden() {
        let sets = HiddenSets(store: makeStore())
        sets.hidden = ["a"]
        sets.alwaysHidden = ["b"]
        sets.isHiddenSetShown = true
        #expect(sets.identifiersToHide(isAlwaysHiddenEnabled: true) == ["b"])
    }

    @Test func disabledAlwaysHiddenIsNeverHidden() {
        let sets = HiddenSets(store: makeStore())
        sets.hidden = ["a"]
        sets.alwaysHidden = ["b"]
        sets.isHiddenSetShown = true
        #expect(sets.identifiersToHide(isAlwaysHiddenEnabled: false).isEmpty)
    }

    @Test func persistsAcrossInstances() {
        let store = makeStore()
        let first = HiddenSets(store: store)
        first.hidden = ["a", "b"]
        first.alwaysHidden = ["c"]
        first.isHiddenSetShown = true

        let second = HiddenSets(store: store)
        #expect(second.hidden == ["a", "b"])
        #expect(second.alwaysHidden == ["c"])
        #expect(second.isHiddenSetShown)
    }
}
