import AppKit
import Observation

/// The apps a picker can list: every running app with a regular or accessory
/// activation policy. An app in a set stays listed after it quits, so the
/// user can still uncheck it.
@MainActor
@Observable
final class RunningApps {
    struct Entry: Identifiable, Hashable {
        /// Bundle identifier.
        let id: String
        let name: String
        let icon: NSImage
        let isRunning: Bool

        static func == (lhs: Entry, rhs: Entry) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    private(set) var running: [Entry] = []
    private var observers: [Task<Void, Never>] = []

    init() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        let names = [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification]
        observers = names.map { name in
            let changes = center.notifications(named: name)
            return Task { [weak self] in
                for await _ in changes.map({ _ in () }) {
                    self?.refresh()
                }
            }
        }
    }

    /// Entries for a picker: the running apps plus the apps in `selected` that
    /// are not running, sorted by name.
    func entries(including selected: Set<String>) -> [Entry] {
        let runningIDs = Set(running.map(\.id))
        let quit = selected.subtracting(runningIDs).map(Self.lookUp)
        return (running + quit).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func refresh() {
        let own = Bundle.main.bundleIdentifier
        var seen = Set<String>()
        running = NSWorkspace.shared.runningApplications.compactMap { app in
            guard [.regular, .accessory].contains(app.activationPolicy),
                  let id = app.bundleIdentifier, id != own,
                  seen.insert(id).inserted
            else { return nil }
            return Entry(
                id: id,
                name: app.localizedName ?? id,
                icon: app.icon ?? Self.genericIcon,
                isRunning: true
            )
        }
    }

    private static let genericIcon = NSWorkspace.shared.icon(for: .applicationBundle)

    /// Name and icon of an app that is not running, from LaunchServices.
    private static func lookUp(_ id: String) -> Entry {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            return Entry(id: id, name: id, icon: genericIcon, isRunning: false)
        }
        return Entry(
            id: id,
            name: FileManager.default.displayName(atPath: url.path),
            icon: NSWorkspace.shared.icon(forFile: url.path),
            isRunning: false
        )
    }
}
