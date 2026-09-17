# Ellipsis — implementation plan

Each phase ends with a jj change that builds and runs. Phase 0 is a go/no-go gate.

## Phase 0: Spike — prove the hide method on macOS 27

Goal: make sure that the large-length divider method works on macOS 27 before any real code.

1. Create `Package.swift` with one executable target `Ellipsis`, platform `.macOS(.v27)`, Swift 6 language mode.
2. Write a minimal `main.swift` with `NSApplication`, one `NSStatusItem` icon and one divider `NSStatusItem`.
3. Click the icon to toggle the divider length between 20 and 10,000.
4. Write `scripts/bundle.sh`. It copies the binary into `build/Ellipsis.app/Contents/MacOS`, writes `Info.plist` with `LSUIElement = true`, and does an ad-hoc `codesign`.
5. Run the app. Cmd+drag a third-party item to the left of the divider. Toggle.

Exit criteria: acceptance criteria 1 and 2 pass. If the method fails, stop and research Thaw's macOS 26 fixes before you continue.

Deliverables: `Package.swift`, `Sources/Ellipsis/main.swift`, `scripts/bundle.sh`, `Resources/Info.plist`.

## Phase 1: App skeleton

1. Replace `main.swift` with `EllipsisApp.swift` (`@main`, SwiftUI `App`) and an `AppDelegate` via `NSApplicationDelegateAdaptor`.
2. Add a `Settings` scene with an empty view.
3. Add `MenuBarManager` (`@MainActor`, `@Observable`). It owns all `NSStatusItem` instances.
4. Add `ControlItem`: wraps one `NSStatusItem`, has `kind` (`icon`, `hiddenDivider`, `alwaysHiddenDivider`) and `isExpanded`.
5. Add `Section` enum: `visible`, `hidden`, `alwaysHidden`.
6. Add `AppState` for persisted settings, backed by `UserDefaults` through `@AppStorage` keys.
7. Give every `NSStatusItem` an `autosaveName` so positions persist.

Exit criteria: the app runs, shows the icon and both dividers, and the always-hidden divider has zero length.

## Phase 2: F1 and F2 — hide, show, always-hidden

1. Implement `MenuBarManager.toggle(section:)`. Hidden divider length switches between normal and 10,000.
2. Icon image switches between `…` and `‹`. Use SF Symbols `ellipsis` and `chevron.left` as templates.
3. Persist `isHiddenSectionShown` and restore it at launch.
4. Option+click on the icon shows both sections and sets the always-hidden divider to a visible length.
5. Right-click on the icon opens an `NSMenu` with "Show always-hidden items", "Settings…", "Quit".
6. Setting: always-hidden section on or off. Off removes the second divider.

Exit criteria: acceptance criteria 2, 3 and 4 pass.

## Phase 3: F3 — auto-rehide

1. `RehideTimer`: a `Task` that sleeps for the timeout, then calls `hide`. Cancel it on manual hide.
2. Click outside: `NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown])`. If the click is not inside the menu bar frame, call `hide`.
3. Focus change: observe `NSWorkspace.didActivateApplicationNotification` and `activeSpaceDidChangeNotification`.
4. Menu-open guard: track the menu bar with `NSMenu.didBeginTrackingNotification` and `didEndTrackingNotification`. Do not hide while a menu is open. Retry after it closes.
5. Settings for each condition and the timeout value.

Exit criteria: acceptance criteria 5, 6 and 7 pass. Make sure that step 2 works with no Accessibility permission. If it does not, add a permission prompt and note it in the spec.

## Phase 4: F4 — Settings window

1. `SettingsView` with a `Form`: launch at login, always-hidden switch, three rehide switches, timeout stepper.
2. Launch at login through `SMAppService.mainApp`.
3. Instruction text for Cmd+drag.
4. About section: version from `Bundle.main`, quit button.
5. Open the window from the right-click menu. Bring the app to the front when the window opens.

Exit criteria: every control changes behavior at once, no restart.

## Phase 5: Release pipeline

1. App icon: `Resources/AppIcon.icns` from a 1024px PNG via `iconutil`.
2. `Resources/Ellipsis.entitlements` with hardened runtime and no sandbox.
3. `scripts/sign.sh`: `codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID"`.
4. `scripts/notarize.sh`: `xcrun notarytool submit --wait`, then `xcrun stapler staple`. Credentials from `notarytool store-credentials` keychain profile named by `$NOTARY_PROFILE`.
5. `scripts/release.sh`: `swift build -c release`, bundle, sign, notarize, zip with `ditto`.
6. `README.md`: build and install instructions.

Exit criteria: acceptance criteria 8 and 9 pass on a clean checkout.

## Phase 6: Polish (optional)

- Notch handling: if the screen has a notch, use the notch frame in click-outside checks.
- Multiple displays: make sure that the menu bar frame check uses the screen that has the menu bar.
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
    ControlItem.swift
    Section.swift
    RehideMonitor.swift
  Settings/
    SettingsView.swift
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
```

## Testing

- Unit tests for `AppState` defaults and `RehideMonitor` decision logic (pure functions: "given this event and this frame, hide or not").
- Manual tests for the acceptance criteria. Keep a checklist in `docs/testing.md` after Phase 2.
- `NSStatusItem` behavior cannot run in a unit test. Do not mock it.

## Research before Phase 0

- Read Ice `ControlItem.swift` and `MenuBarSection.swift` for the length trick and edge cases.
- Read Thaw's changelog for macOS 26 fixes. Some can also apply to 27.
- Make sure that `NSStatusItem.autosaveName` still persists position on macOS 27.
