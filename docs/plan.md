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
8. `scripts/run.sh`: bundle, copy to `/Applications/Ellipsis.app`, launch. `MenuBarAgent` only matches apps in `/Applications` (see `docs/phase0.md`).

Exit criteria: the app runs, shows the icon, and applies the persisted sets at launch.

## Phase 2: F1 and F2 — hide, show, always-hidden

1. Implement `MenuBarManager.toggle()`. Hidden: restriction hides both sets. Shown: restriction hides only the always-hidden set. Shown with Option: no restriction.
2. Icon image switches between `…` and `‹`. Use the Ellipsis asset from Ice (`Ice/Assets.xcassets/ControlItemImages/Ellipsis`) as the default `…` image. Use SF Symbol `chevron.left` for `‹`.
3. Persist `isHiddenSetShown` and restore it at launch.
4. Right-click on the icon opens an `NSMenu` with "Show always-hidden items", "Settings…", "Quit".
5. Setting: always-hidden set on or off. Off means the always-hidden set is never hidden.
6. Release the restriction on quit (`applicationWillTerminate`).
7. Test the clock click under a restriction (acceptance criterion 8). If it fails, add a global mouse-down monitor. On a mouse-down in the menu bar that is not on the Ellipsis icon, release the restriction for one second, then apply it again.

Exit criteria: acceptance criteria 2, 3, 4, 8 and 9 pass.

## Phase 3: F3 — auto-rehide

1. `RehideTimer`: a `Task` that sleeps for the timeout, then calls `hide`. Cancel it on manual hide.
2. Click outside: `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown])`. If the click is not inside the menu bar frame, call `hide`.
3. Focus change: observe `NSWorkspace.didActivateApplicationNotification` and `activeSpaceDidChangeNotification`.
4. Menu-open guard: track the menu bar with `NSMenu.didBeginTrackingNotification` and `didEndTrackingNotification`. Do not hide while a menu is open. Retry after it closes.
5. Settings for each condition and the timeout value.

Exit criteria: acceptance criteria 5, 6 and 7 pass. Make sure that step 2 works with no Accessibility permission. If it does not, add a permission prompt and note it in the spec.

## Phase 4: F4 — Settings window

1. `SettingsView` with a `Form`: launch at login, always-hidden switch, three rehide switches, timeout stepper.
2. `AppPicker`: a list of running apps from `NSWorkspace.shared.runningApplications` with a checkbox per app. Show the app icon and name. Filter to `.regular` and `.accessory` activation policies. Refresh on `NSWorkspace.didLaunchApplicationNotification` and `didTerminateApplicationNotification`. Keep checked apps in the list after they quit.
3. Two `AppPicker` instances: hidden set and always-hidden set. An app can be in one set only.
4. Launch at login through `SMAppService.mainApp`.
5. About section: version from `Bundle.main`, quit button.
6. Open the window from the right-click menu. Bring the app to the front when the window opens.

Exit criteria: every control changes behavior at once, no restart.

## Phase 5: Release pipeline

1. App icon: `Resources/AppIcon.icns` from a 1024px PNG via `iconutil`.
2. `Resources/Ellipsis.entitlements` with hardened runtime and no sandbox. Hardened runtime must permit `dlopen` of a system framework. No extra entitlement is necessary for system frameworks.
3. `scripts/sign.sh`: `codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID"`.
4. `scripts/notarize.sh`: `xcrun notarytool submit --wait`, then `xcrun stapler staple`. Credentials from `notarytool store-credentials` keychain profile named by `$NOTARY_PROFILE`.
5. `scripts/release.sh`: `swift build -c release`, bundle, sign, notarize, zip with `ditto`.
6. `README.md`: build and install instructions. State the private-API risk and the Focus limit.

Exit criteria: acceptance criteria 1, 10 and 11 pass on a clean checkout.

## Phase 6: Polish (optional)

- Position-based sets: ask the user to select the `MenuBarAgent` layout table in a file panel once. Then apps left of an Ellipsis divider item join the hidden set. This restores the Cmd+drag workflow.
- Sparkle or manual update check. Not in v1.

## File layout

```
Package.swift
Sources/Ellipsis/
  EllipsisApp.swift
  AppDelegate.swift
  AppState.swift
  MenuBar/
    MenuBarManager.swift
    MenuBarRestriction.swift
    HiddenSets.swift
    RehideMonitor.swift
  Settings/
    SettingsView.swift
    AppPicker.swift
Resources/
  Info.plist
  Ellipsis.entitlements
  AppIcon.icns
scripts/
  bundle.sh
  sign.sh
  notarize.sh
  release.sh
docs/
  spec.md
  plan.md
  phase0.md
```

## Testing

- Unit tests for `HiddenSets` (which bundle identifiers a state produces), `AppState` defaults, and `RehideMonitor` decision logic (pure functions: "given this event and this frame, hide or not").
- Manual tests for the acceptance criteria. Keep a checklist in `docs/testing.md` after Phase 2.
- `MenuBarRestriction` talks to `MenuBarAgent`. Do not mock it. Test it by hand.
