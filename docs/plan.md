# Ellipsis — implementation plan

Each phase ends with a jj change that builds and runs.

## Phase 0: Spike — done

See `docs/phase0.md`. The large-length method failed. The assessment-mode restriction works. The spike in `Sources/Ellipsis/main.swift` shows one icon. A click toggles a restriction that hides the bundle identifiers in the `hiddenBundleIdentifiers` user default.

Deliverables: `Package.swift`, `Sources/Ellipsis/main.swift`, `scripts/bundle.sh`, `Resources/Info.plist`, `docs/phase0.md`.

## Phase 1: App skeleton — done

1. Replace `main.swift` with `EllipsisApp.swift` (`@main`, SwiftUI `App`) and an `AppDelegate` via `NSApplicationDelegateAdaptor`.
2. Add a `Settings` scene with an empty view.
3. Add `MenuBarRestriction`: a wrapper around the private `MBAssessmentMode*` classes. It loads `MenuBarClientCore` with `dlopen`, resolves the classes, and exposes `apply(hiddenBundleIdentifiers:)` and `release()`. It holds one assertion at a time. It reports an error if the classes do not exist.
4. Add `MenuBarManager` (`@MainActor`, `@Observable`). It owns the `NSStatusItem` for the icon and the `MenuBarRestriction`.
5. Add `HiddenSets`: the hidden set, the always-hidden set, and `isHiddenSetShown`, persisted in `UserDefaults`.
6. Add `AppState` for the other settings, backed by `UserDefaults` through `@AppStorage` keys.
7. At launch, if the private classes do not exist, show an alert and quit.
8. `scripts/run.sh`: bundle, copy to `/Applications`, launch. A debug build is `EllipsisDev.app` with the identifier `au.ronny.EllipsisDev`, so it runs next to a release build with its own settings. `MenuBarAgent` only matches apps in `/Applications` (see `docs/phase0.md`).

Exit criteria: the app runs, shows the icon, and applies the persisted sets at launch.

## Phase 2: F1 and F2 — hide, show, always-hidden — done

1. Implement `MenuBarManager.toggle()`. Hidden: restriction hides both sets. Shown: restriction hides only the always-hidden set. Shown with Option: no restriction.
2. Icon image switches between `…` and `‹`. Use SF Symbols `ellipsis` and `chevron.left`. Ice is GPL-3, so its Ellipsis asset stays out of this repository.
3. Persist `isHiddenSetShown` and restore it at launch.
4. Right-click on the icon opens an `NSMenu` with "Show always-hidden items", "Settings…", "Quit".
5. Setting: always-hidden set on or off. Off means the always-hidden set is never hidden. `MenuBarManager` observes the sets and this setting with `withObservationTracking`, so any writer, including the Settings window, changes the restriction at once.
6. Release the restriction on quit (`applicationWillTerminate`).
7. Clock click under a restriction fails (acceptance criterion 8), and `MenuBarAgent` decides at mouse-down, so a release on mouse-down is too late. A global mouse-move monitor releases the restriction while the pointer is in the trailing zone of the menu bar, 300 points until Phase 6 sizes it.

Exit criteria: acceptance criteria 2, 3, 4, 8 and 9 pass. Checklist in `docs/testing.md`.

## Phase 3: F3 — auto-rehide — done

1. `RehideMonitor`: armed when the hidden set becomes shown, disarmed when it hides. A timer `Task` sleeps for the timeout, then hides. A settings change while armed reinstalls the monitors.
2. Click outside: `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown])`. A click in the menu bar or inside an open menu does not hide. Works with no Accessibility permission.
3. Focus change: `NSWorkspace.didActivateApplicationNotification` (not for Ellipsis itself) and `activeSpaceDidChangeNotification`.
4. Menu-open guard: `NSMenu.didBeginTrackingNotification` only fires for menus in the Ellipsis process, so other apps' status item menus are found with `CGWindowListCopyWindowInfo`. A window at the pop-up menu level whose top edge touches the menu bar is an open menu. Deprecated since macOS 14 but needs no permission, unlike `SCShareableContent`. A hide that finds a menu open retries every 300 ms.
5. `RehidePolicy` holds the pure decisions, with tests. `MenuBarGeometry` holds the menu bar frames and the clock zone.
6. Settings: three switches and the timeout stepper.

Exit criteria: acceptance criteria 5, 6 and 7 pass.

## Phase 4: F4 — Settings window — done

1. `SettingsView` is a `TabView`: General (launch at login, rehide switches, timeout stepper, About), Hidden (app picker), Always Hidden (the enable switch and an app picker).
2. `RunningApps`: the running apps from `NSWorkspace.shared.runningApplications` with a `.regular` or `.accessory` activation policy, minus Ellipsis. Refreshes on `didLaunchApplicationNotification` and `didTerminateApplicationNotification`. An app in a set that is not running stays listed, with its name and icon from LaunchServices, so the user can uncheck it.
3. `AppPicker`: rows for a `Form` section, one checkbox per app with icon and name. An app can be in one set only: a check in one set removes the app from the other. The row shows which set holds the app.
4. `LaunchAtLogin` wraps `SMAppService.mainApp`. The service status is the source of truth. `requiresApproval` shows a button that opens Login Items in System Settings.
5. About section: version from `Bundle.main`, quit button.
6. The right-click menu opens the window and activates the app (Phase 2).

Exit criteria: every control changes behavior at once, no restart. `MenuBarManager` observes the sets and `AppState`, so a checkbox changes the restriction on the spot.

## Phase 5: Release pipeline — done

1. App icon: `scripts/make-icon-art.swift` draws `Resources/AppIcon.png` (three dots on a dark rounded square). `scripts/make-icon.sh` turns it into `Resources/AppIcon.icns` with `sips` and `iconutil`. Both files are committed.
2. `Resources/Ellipsis.entitlements`: hardened runtime, no sandbox, no entitlements. `MenuBarClientCore` is Apple-signed, so library validation permits the `dlopen`. Tested: the hardened build hides items.
3. `scripts/sign.sh`: `codesign --force --options runtime --timestamp`. `DEVELOPER_ID` names the identity; default is the first Developer ID Application identity in the keychain. A revoked certificate is refused.
4. `scripts/notarize.sh`: `notarytool submit --wait`, `stapler staple`, `stapler validate`, `spctl --assess`. `NOTARY_PROFILE` names the keychain profile; default `ellipsis`.
5. `scripts/release.sh X.Y.Z`: bundle a release build with `VERSION` and `BUILD` (the commit count), sign, notarize, zip with `ditto` to `build/Ellipsis-X.Y.Z.zip`.
6. `README.md`: install, build and release instructions, the private-API risk and the Focus limit.

Exit criteria: acceptance criteria 1, 10 and 11 pass on a clean checkout.

## Phase 5b: Optional Accessibility permission — done

`AccessibilityPermission` (trust state, opt-out flag, the explanation dialog) and an `AXExtrasMenuBar` scan in `RunningApps` that filters the pickers. The scan runs off the main thread with a 0.2 s timeout per app: an unresponsive app must not block Settings. Spec F6.

## Phase 6: Polish (optional)

- Position-based sets — done, with the icon as the divider (spec F7). The plan was a file panel for the `MenuBarAgent` layout table, which needs Full Disk Access or a one-time pick. `MenuBarLayout` (Accessibility, see the clock zone below) gives the visible items and their owners with no file, so that is used instead. A first version had a separate divider item; the icon does the same job with one item fewer, as in Ice and Bartender. `IconDivider` reads the layout after a Cmd-drag (a mouse-up with Cmd held: the global monitor for other apps' items, a local one for the icon itself), after a launch, and when the set is shown. `DividerPolicy` holds the set arithmetic, with tests. Only visible items are readable, so a hidden app keeps its membership until the set is shown.
- Clock zone calibration — done. `MenuBarLayout` reads the windows of `MenuBarAgent` over Accessibility: one slot per item with its frame and owner pid, and `com.apple.menuextra.clock` for the clock. `ClockZone` sets `clockZoneWidth` to the clock offset plus a 30-point margin at launch, when the permission arrives, and when Settings opens. Without the permission, "Click the Clock…" in General takes the width from one click on the clock's left edge. Measured with synthetic clicks: a 1-point zone never opens Notification Center, a 40-point zone (2 points of margin) opens it from a 10,000 points/s approach.
- Export and import settings — done. "Export…" and "Import…" buttons in General. `SettingsFile` writes the settings keys (not the shown state, not the Accessibility opt-out) to a plist through `NSSavePanel`, and reads one back through `NSOpenPanel`. Import checks each known key's type, ignores unknown keys, and writes key by key so AppKit's own keys in the domain stay. `AppState` and `HiddenSets` reload from the store afterwards.
- Updates — done, with Sparkle 2 from SwiftPM. `Updater` wraps `SPUStandardUpdaterController` for the "Check for Updates…" menu item and the About section in General. `bundle.sh` copies `Sparkle.framework` into `Contents/Frameworks`, `sign-sparkle.sh` signs its XPC services and helpers for notarization, and `release.sh` writes `build/appcast.xml` with `generate_appcast`. `publish.sh` uploads the zip and the appcast to the GitHub release, and `SUFeedURL` reads the appcast from `releases/latest/download/`, so no other host is necessary. A debug build never checks on its own (`SUEnableAutomaticChecks` is false), so it does not replace itself with a release.

## Phase 7: VM test framework

The acceptance criteria are tested by hand, on the developer's own menu bar. That blocks the desktop while a test runs, an agent cannot run them, and the record of a pass is a word in `docs/testing.md`. This phase runs the app in a macOS virtual machine and drives it from a test target. There is no macOS simulator; the VM is the substitute. Notch behavior is out of scope: a virtual display has no notch (Phase 8).

The VM is a [Tart](https://tart.run) guest, cloned from `ghcr.io/cirruslabs/macos-golden-gate-base` (macOS 27, `admin`/`admin`, auto-login, sshd, VNC, Gatekeeper off, SIP on). The host builds everything. The guest gets the app, the fixture app and the probe over `scp`, and runs them over `ssh`. `tart clone` is an APFS clone, so one clone per test run is cheap and every run starts from the same state.

1. Spike. Install `tart` (`brew install cirruslabs/cli/tart`), pull the base image, clone it, boot it. Over `ssh`: post one `CGEvent` click, read `MenuBarLayout`, take a `screencapture`. Record the result in `docs/phase7.md` in the format of `docs/phase0.md`. Questions:
   - Whether a process started by `sshd` can post `CGEvent`s to the auto-login session, or needs `launchctl asuser`.
   - Which process the Accessibility and Screen Recording grants go to. The expectation is `/usr/libexec/sshd-keygen-wrapper`, so one grant covers every `ssh` command and a rebuilt binary keeps it.
   - Whether `MenuBarAgent` in the guest hides an app in `/Applications` under a restriction the same way as on the host.
   - Whether `screencapture` over `ssh` returns the screen or a black image.
2. Golden VM. `scripts/vm.sh prepare` clones the base image as `ellipsis-golden`, sets CPU, memory and display size, and boots it with VNC. A checklist in `docs/development.md` lists the steps that need a hand: the two grants in System Settings, a 24-hour clock so the clock zone is stable. `scripts/vm.sh` also has `clone`, `ip`, `ssh`, `scp`, `delete`. The VM name comes from `ELLIPSIS_VM`, default `ellipsis-test`.
3. Fixture app. `Sources/Fixture/main.swift`: one status item with a menu. Its title and bundle identifier come from `Info.plist`, so `scripts/bundle.sh fixture N` writes `FixtureN.app` with `au.ronny.EllipsisFixture.N`. Tests need apps that own menu bar items with known identifiers, and a guest has none. The item's menu has one entry that writes a file, so a test can see that click-through reached the app.
4. Probe. `Sources/Probe/main.swift`, an executable target with no AppKit UI. Subcommands, each printing JSON: `layout` (`MenuBarLayout.read()`, with the frames), `click X Y [--option] [--right] [--command]` (`CGEvent` mouse down and up at a point in Accessibility coordinates), `move X Y`, `drag X1 Y1 X2 Y2 [--command]`, `windows` (`MenuBarGeometry.openMenuFrames()`), `screenshot PATH`. `MenuBarLayout` and `MenuBarGeometry` move to a library target `EllipsisCore` that `Ellipsis`, `Probe` and the tests link. The probe is the only thing that touches the guest's screen, so the tests hold no AppKit state of their own.
5. Test target. `Tests/EllipsisVMTests`, swift-testing, on the host. A `Guest` type wraps `ssh` and `scp` to the VM at `ELLIPSIS_VM`: `run`, `copy`, `launch(app)`, `quit(app)`, `defaults(write:)`, `probe(_:)` decoded from JSON. Every test is skipped when `ELLIPSIS_VM` is unset, so `mise run test` stays a unit test run. A `MenuBar` helper on top of `Guest` gives `items() -> [bundleID]`, `iconFrame()`, `clickIcon(option:)`, `waitUntil(_:timeout:)` with polling, since `MenuBarAgent` lays out asynchronously.
6. Test run. `scripts/vm-test.sh`: build, bundle the app, three fixtures and the probe, `tart clone ellipsis-golden $ELLIPSIS_VM`, `tart run --no-graphics` in the background, wait for `ssh`, copy the bundles to `/Applications`, run `swift test --filter EllipsisVMTests`, copy `~/screenshots` from the guest to `build/vm-screenshots`, `tart delete`. `mise run vm-test` runs it. A failed test leaves the VM running when `ELLIPSIS_VM_KEEP` is set, for a look over VNC.
7. Settings in tests come from `defaults write au.ronny.EllipsisDev` before the launch, not from the Settings window. The Settings window is a SwiftUI form; the acceptance criteria are about the menu bar. Each test launches the app with the settings it needs and quits it at the end. A test for a settings change while the app runs (5a, 4b, D5) uses `defaults write` and then checks that the app picked it up; if `AppState` does not observe external writes, the test relaunches and the criterion stays manual.
8. Tests. One test per row of `docs/testing.md` that the guest can run: 2, 3, 4, 4b, 5, 5a, 5b, 6, 6a, 6b, 7, 7a, 8 (the clock zone, with `click` at the clock frame from `layout`), 9, 9a, D1 to D5, and S7 to S9 through the export file. Rows that stay manual, with the reason in the checklist: 1 to 1b (the permission dialog), 4a and 6c (a right-click menu drawn by Ellipsis; the probe can click it, but the menu items are found by frame only), 8a and 8b (the Settings window), S1 to S6 (the Settings window), 10 and 11 (release scripts). The Result column of a row with a test says `vm`.
9. CI. `.github/workflows/vm-test.yml` on `runs-on: self-hosted` with `mise run vm-test`. GitHub's hosted macOS runners are VMs with no nested virtualization, so the runner is a Mac with `tart` and the golden VM. Apple allows two macOS guests per host, so the workflow has `concurrency` set to one run at a time. The workflow is a deliverable only once a runner exists; until then the script is the CI.
10. Docs: `docs/development.md` (the golden VM checklist, `mise run vm-test`, `ELLIPSIS_VM`, `ELLIPSIS_VM_KEEP`), `docs/testing.md` (which rows have a test), this file.

Exit criteria: `mise run vm-test` passes on a clean checkout with the golden VM present, with no pointer or menu bar change on the host. Every row it covers is marked in `docs/testing.md`.

## Phase 8: F8 — the floating bar

Displays with a notch drop the shown items that do not fit. Spec F8. The bar works on every display, so every step but the spike is built on the desktop and tested in the VM (Phase 7). A virtual display has no notch, but the same drop happens when the status item region ends at the front app's menus: a narrow VM display (`tart set --display`) and a fixture with a wide menu bar reproduce it. `NSScreen.safeAreaInsets` stays zero in the VM, so the placement default takes the insets as a parameter and has a unit test.

1. Spike on the laptop with a notch. Record the result in `docs/phase8.md` in the format of `docs/phase0.md`. Questions:
   - What `MenuBarAgent` does with an item that does not fit right of the notch: not drawn, drawn left of the notch, or drawn under it.
   - Whether `MenuBarLayout` reports a frame for such an item. The expectation is no.
   - Whether a restriction that allows one app puts that app's item right of the notch.
   - The frame of the Ellipsis icon window and `NSScreen.safeAreaInsets` on that display.
   - Whether the notch boundary and the app-menu boundary produce the same layout, so the VM test stands for the notch.
2. Add `AppState.hiddenItemsPlacement` (`menuBar` or `floatingBar`) and the "Show hidden items" picker in General. The default comes from `NSScreen.safeAreaInsets.top` at first launch.
3. Add `FloatingBarPlacement`: a pure function from the icon frame, the screen and the panel size to the panel frame. Unit tests.
4. Add `FloatingBar`: the `NSPanel`, an `NSHostingView` with an `HStack` of 18-point app icons, tooltips, hover. It takes the bundle identifiers to show and a click handler.
5. Change `MenuBarManager.applyCurrentState`. In bar mode, `isHiddenSetShown` keeps the restriction and shows the panel. The panel content is `sets.hidden`, plus `sets.alwaysHidden` when `isAlwaysHiddenSetShown`. `RehideMonitor` stays as it is: the panel is non-activating, so it causes no focus change, and its own clicks do not reach the global monitor. `RehidePolicy` must treat a click inside the panel frame as inside.
6. Click-through. Keep the owner `AXUIElement` in `MenuBarLayout.Item` behind a `Sendable` wrapper. On a click in the bar: apply a restriction that hides every running app except the target and Ellipsis. Wait for the activation and a 400 ms settle (the `IconDivider` delay). Read the layout and `AXPress` the owner element with a 1 s messaging timeout. Close the panel. Poll `MenuBarGeometry.openMenuFrames()` every 300 ms. When no menu is open, `applyCurrentState()`.
7. Without the Accessibility permission, the click applies the single-app restriction and arms the rehide. The tooltip says what the permission adds.
8. Docs: README (feature and the app-icon limit), `docs/testing.md` checklist, this file.
9. VM tests: show with a narrow display drops an item; bar mode shows every app; a click in the bar opens the fixture's menu; each rehide condition closes the bar.

Exit criteria: on the laptop, a click on the icon shows every hidden app in the bar, a click on an app in the bar opens its menu, and the bar closes on each rehide condition.

## File layout

```
Package.swift
Sources/EllipsisCore/
  MenuBarLayout.swift
  MenuBarGeometry.swift
Sources/Fixture/
  main.swift
Sources/Probe/
  main.swift
Sources/Ellipsis/
  EllipsisApp.swift
  AppDelegate.swift
  AppState.swift
  Accessibility/
    AccessibilityPermission.swift
  MenuBar/
    MenuBarManager.swift
    MenuBarRestriction.swift
    HiddenSets.swift
    RehideMonitor.swift
    RehidePolicy.swift
    IconDivider.swift
    DividerPolicy.swift
    ClockZone.swift
    FloatingBar.swift
    FloatingBarPlacement.swift
  Settings/
    SettingsWindow.swift
    SettingsView.swift
    AppPicker.swift
    RunningApps.swift
    LaunchAtLogin.swift
Tests/EllipsisTests/
Tests/EllipsisVMTests/
  Guest.swift
  MenuBar.swift
  *Tests.swift
Resources/
  Info.plist
  Fixture-Info.plist
  Ellipsis.entitlements
  AppIcon.png
  AppIcon.icns
scripts/
  bundle.sh
  run.sh
  make-icon-art.swift
  make-icon.sh
  sign.sh
  notarize.sh
  release.sh
  vm.sh
  vm-test.sh
docs/
  spec.md
  plan.md
  phase0.md
  phase7.md
  phase8.md
```

## Testing

- Unit tests for `HiddenSets` (which bundle identifiers a state produces), `AppState` defaults, and `RehidePolicy` (pure functions: "given this click, these menus and this frame, hide or not").
- VM tests for the acceptance criteria that a guest can run (Phase 7). `mise run vm-test`.
- Manual tests for the rest. The checklist in `docs/testing.md` says which rows have a VM test.
- `MenuBarRestriction` talks to `MenuBarAgent`. Do not mock it. Test it by hand.
