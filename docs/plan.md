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

- Position-based sets: ask the user to select the `MenuBarAgent` layout table in a file panel once. The XPC route (`getPreferredTrailingItemPositions:`) needs a private entitlement, so the file panel stays. Then apps left of an Ellipsis divider item join the hidden set. This restores the Cmd+drag workflow.
- Clock zone calibration — done. `MenuBarLayout` reads the windows of `MenuBarAgent` over Accessibility: one slot per item with its frame and owner pid, and `com.apple.menuextra.clock` for the clock. `ClockZone` sets `clockZoneWidth` to the clock offset plus a 30-point margin at launch, when the permission arrives, and when Settings opens. Without the permission, "Click the Clock…" in General takes the width from one click on the clock's left edge. Measured with synthetic clicks: a 1-point zone never opens Notification Center, a 40-point zone (2 points of margin) opens it from a 10,000 points/s approach.
- Export and import settings — done. "Export…" and "Import…" buttons in General. `SettingsFile` writes the settings keys (not the shown state, not the Accessibility opt-out) to a plist through `NSSavePanel`, and reads one back through `NSOpenPanel`. Import checks each known key's type, ignores unknown keys, and writes key by key so AppKit's own keys in the domain stay. `AppState` and `HiddenSets` reload from the store afterwards.
- Sparkle or manual update check. Not in v1.

## File layout

```
Package.swift
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
    MenuBarGeometry.swift
  Settings/
    SettingsWindow.swift
    SettingsView.swift
    AppPicker.swift
    RunningApps.swift
    LaunchAtLogin.swift
Resources/
  Info.plist
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
docs/
  spec.md
  plan.md
  phase0.md
```

## Testing

- Unit tests for `HiddenSets` (which bundle identifiers a state produces), `AppState` defaults, and `RehidePolicy` (pure functions: "given this click, these menus and this frame, hide or not").
- Manual tests for the acceptance criteria. Keep a checklist in `docs/testing.md` after Phase 2.
- `MenuBarRestriction` talks to `MenuBarAgent`. Do not mock it. Test it by hand.
