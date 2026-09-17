import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        Form {
            Section {
                Toggle("Keep an always-hidden set", isOn: $state.isAlwaysHiddenEnabled)
            }
            Section("Hide again") {
                Toggle("After a timeout", isOn: $state.rehideOnTimeout)
                Stepper(value: $state.rehideTimeout, in: 1...300, step: 1) {
                    Text("\(Int(state.rehideTimeout)) seconds")
                }
                .disabled(!state.rehideOnTimeout)
                Toggle("On a click outside the menu bar", isOn: $state.rehideOnClickOutside)
                Toggle("When the front app or Space changes", isOn: $state.rehideOnFocusChange)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 300)
    }
}
