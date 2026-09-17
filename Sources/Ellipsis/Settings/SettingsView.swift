import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @Environment(HiddenSets.self) private var sets
    @Environment(RunningApps.self) private var apps
    @Environment(AccessibilityPermission.self) private var permission

    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettings()
            }
            Tab("Hidden", systemImage: "eye.slash") {
                Form {
                    Section {
                        AppPicker(
                            apps: apps.entries(including: sets.hidden),
                            selection: hiddenSelection,
                            otherSet: sets.alwaysHidden,
                            otherSetName: "Always hidden"
                        )
                    } header: {
                        Text("Hidden apps")
                    } footer: {
                        Text("These apps hide until you click the Ellipsis icon.")
                    }
                }
                .formStyle(.grouped)
            }
            Tab("Always Hidden", systemImage: "eye.slash.fill") {
                @Bindable var state = state
                Form {
                    Section {
                        Toggle("Keep an always-hidden set", isOn: $state.isAlwaysHiddenEnabled)
                    } footer: {
                        Text("Option-click the Ellipsis icon to show these apps.")
                    }
                    Section("Always-hidden apps") {
                        AppPicker(
                            apps: apps.entries(including: sets.alwaysHidden),
                            selection: alwaysHiddenSelection,
                            otherSet: sets.hidden,
                            otherSetName: "Hidden"
                        )
                    }
                    .disabled(!state.isAlwaysHiddenEnabled)
                }
                .formStyle(.grouped)
            }
        }
        .frame(width: 480, height: 460)
        .onAppear {
            permission.refresh()
            apps.refresh()
        }
        .onChange(of: permission.isTrusted) { apps.refresh() }
    }

    /// An app can be in one set only, so a check here removes it from the other set.
    private var hiddenSelection: Binding<Set<String>> {
        Binding(
            get: { sets.hidden },
            set: { new in
                sets.alwaysHidden.subtract(new)
                sets.hidden = new
            }
        )
    }

    private var alwaysHiddenSelection: Binding<Set<String>> {
        Binding(
            get: { sets.alwaysHidden },
            set: { new in
                sets.hidden.subtract(new)
                sets.alwaysHidden = new
            }
        )
    }
}

private struct GeneralSettings: View {
    @Environment(AppState.self) private var state
    @Environment(LaunchAtLogin.self) private var loginItem
    @Environment(AccessibilityPermission.self) private var permission

    var body: some View {
        @Bindable var state = state
        Form {
            Section {
                Toggle(
                    "Launch at login",
                    isOn: Binding(get: { loginItem.isEnabled }, set: loginItem.set)
                )
                if loginItem.needsApproval {
                    LabeledContent("Waiting for approval in System Settings") {
                        Button("Open Login Items", action: loginItem.openSystemSettings)
                    }
                }
                if let error = loginItem.error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
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
            Section {
                LabeledContent("Accessibility") {
                    if permission.isTrusted {
                        Text("Granted")
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Grant Permission…", action: permission.ask)
                    }
                }
            } footer: {
                Text(permission.isTrusted
                    ? "The app pickers list only the apps that have a menu bar item."
                    : "Optional. With it, the app pickers list only the apps that have a menu bar item.")
            }
            Section("About") {
                LabeledContent("Version", value: Self.version)
                Button("Quit Ellipsis") {
                    NSApp.terminate(nil)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: loginItem.refresh)
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        guard let short = info?["CFBundleShortVersionString"] as? String else { return "development build" }
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }
}
