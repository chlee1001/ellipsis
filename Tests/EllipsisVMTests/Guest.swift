import EllipsisCore
import Foundation
import Testing

/// The Tart guest named by `ELLIPSIS_VM`, reached through `scripts/vm.sh`.
/// The apps and the probe are already in the guest: `scripts/vm-test.sh`
/// puts them there before `swift test` starts.
struct Guest: Sendable {
    static let name = ProcessInfo.processInfo.environment["ELLIPSIS_VM"]
    static var isConfigured: Bool { name != nil }

    static let appIdentifier = "au.ronny.EllipsisDev"
    static let appName = "EllipsisDev"

    struct CommandFailure: Error, CustomStringConvertible {
        var command: String
        var status: Int32
        var output: String
        var description: String { "`\(command)` exited \(status): \(output)" }
    }

    private static let script = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("scripts/vm.sh").path

    /// Runs a shell command in the guest and returns its output.
    @discardableResult
    func run(_ command: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.script)
        process.arguments = ["ssh", command]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else {
            throw CommandFailure(command: command, status: process.terminationStatus, output: output)
        }
        return output
    }

    func probe<T: Decodable>(_ arguments: String, as type: T.Type = T.self) throws -> T {
        let output = try run("./probe \(arguments)")
        return try JSONDecoder().decode(type, from: Data(output.utf8))
    }

    func probe(_ arguments: String) throws {
        try run("./probe \(arguments)")
    }

    // MARK: Apps

    func launch(_ app: String) throws {
        try run("open /Applications/\(app).app")
    }

    func quit(_ app: String) throws {
        try run("pkill -x \(app) || true")
        try waitUntil("\(app) quits") { try run("pgrep -x \(app) || true").isEmpty }
    }

    func kill(_ app: String) throws {
        try run("pkill -9 -x \(app) || true")
    }

    func isRunning(_ app: String) throws -> Bool {
        try !run("pgrep -x \(app) || true").isEmpty
    }

    /// Every test starts with the three fixtures in the menu bar and no
    /// Ellipsis, whatever the last test left behind.
    func startFixtures() throws {
        try quit(Self.appName)
        for id in Fixture.all where try !isRunning(Fixture.name(id)) {
            try launch(Fixture.name(id))
        }
        try waitUntil("the fixtures are in the menu bar") { try appItems().isSuperset(of: Fixture.all) }
    }

    // MARK: Ellipsis

    /// Quits Ellipsis, replaces its settings with `settings` plus what a test
    /// needs to run unattended (no permission dialog, no rehide unless asked
    /// for), and launches it again.
    func launchEllipsis(_ settings: [String: Setting] = [:]) throws {
        try quit(Self.appName)
        try run("defaults delete \(Self.appIdentifier) 2>/dev/null || true")
        var all: [String: Setting] = [
            "accessibilityDeclined": .bool(true),
            "rehideOnTimeout": .bool(false),
            "rehideOnClickOutside": .bool(false),
            "rehideOnFocusChange": .bool(false),
        ]
        all.merge(settings) { _, new in new }
        for (key, value) in all.sorted(by: { $0.key < $1.key }) {
            try run("defaults write \(Self.appIdentifier) \(key) \(value.argument)")
        }
        try launch(Self.appName)
        try waitUntil("the Ellipsis icon appears") { try iconFrame() != nil }
    }

    func setting(_ key: String) throws -> String {
        try run("defaults read \(Self.appIdentifier) \(key)")
    }

    enum Setting {
        case bool(Bool)
        case double(Double)
        case strings([String])

        var argument: String {
            switch self {
            case .bool(let value): "-bool \(value)"
            case .double(let value): "-float \(value)"
            case .strings(let values): "-array " + values.map { "'\($0)'" }.joined(separator: " ")
            }
        }
    }

    // MARK: Menu bar

    func layout() throws -> MenuBarLayout {
        try probe("layout")
    }

    /// The items on the guest's one display, left to right.
    func items() throws -> [MenuBarLayout.Item] {
        try layout().displays.first?.items.sorted { $0.frame.minX < $1.frame.minX } ?? []
    }

    func appItems() throws -> Set<String> {
        Set(try items().compactMap(\.bundleIdentifier))
    }

    func frame(of bundleIdentifier: String) throws -> CGRect? {
        try items().first { $0.bundleIdentifier == bundleIdentifier }?.frame
    }

    func iconFrame() throws -> CGRect? {
        try frame(of: Self.appIdentifier)
    }

    func click(_ frame: CGRect, option: Bool = false, right: Bool = false) throws {
        var arguments = "click \(Int(frame.midX)) \(Int(frame.midY))"
        if option { arguments += " --option" }
        if right { arguments += " --right" }
        try probe(arguments)
    }

    func clickIcon(option: Bool = false) throws {
        guard let frame = try iconFrame() else { throw CommandFailure(command: "icon", status: 1, output: "no Ellipsis icon") }
        try click(frame, option: option)
    }

    func openMenus() throws -> [CGRect] {
        try probe("menus")
    }

    func screenshot(_ name: String) throws {
        try run("mkdir -p screenshots && screencapture -x screenshots/\(name).png")
    }

    /// Polls until `condition` holds. `MenuBarAgent` lays out after the event
    /// that caused it, so no read right after a click is final.
    func waitUntil(
        _ what: String, timeout: TimeInterval = 5, interval: TimeInterval = 0.2,
        sourceLocation: SourceLocation = #_sourceLocation, _ condition: () throws -> Bool
    ) throws {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if try condition() { return }
            Thread.sleep(forTimeInterval: interval)
        }
        Issue.record("timed out waiting until \(what)", sourceLocation: sourceLocation)
    }

    /// Waits until the condition holds and stays for `settle` seconds, for
    /// checks that something did not happen.
    func expectStable(
        _ what: String, for settle: TimeInterval = 1.5, interval: TimeInterval = 0.3,
        sourceLocation: SourceLocation = #_sourceLocation, _ condition: () throws -> Bool
    ) throws {
        let deadline = Date(timeIntervalSinceNow: settle)
        while Date() < deadline {
            guard try condition() else {
                Issue.record("\(what) did not hold", sourceLocation: sourceLocation)
                return
            }
            Thread.sleep(forTimeInterval: interval)
        }
    }
}

enum Fixture {
    static let a = "au.ronny.EllipsisFixture.A"
    static let b = "au.ronny.EllipsisFixture.B"
    static let c = "au.ronny.EllipsisFixture.C"
    static let all = [a, b, c]

    static func name(_ identifier: String) -> String {
        "Fixture" + identifier.split(separator: ".").last!
    }

    static func markerPath(_ identifier: String) -> String {
        "\(identifier).marked"
    }
}
