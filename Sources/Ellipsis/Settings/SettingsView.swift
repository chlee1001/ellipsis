import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        Form {
            Toggle("Keep an always-hidden set", isOn: $state.isAlwaysHiddenEnabled)
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 120)
    }
}
