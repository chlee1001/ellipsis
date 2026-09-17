# Ellipsis — specification

Ellipsis is a macOS menu bar item manager. It hides and shows menu bar items of other apps. It is a stripped-down version of [Ice](https://github.com/jordanbaird/Ice) and [Bartender](https://www.macbartender.com) for macOS 27 (Golden Gate).

## Goals

- Hide and show menu bar items with one click.
- Keep an "always hidden" set of apps that you never want to see.
- Rehide the items automatically after a timeout or after a click outside the menu bar.
- Ask for no permission. No Accessibility, no Screen Recording, no Full Disk Access.
- Build with SwiftPM and shell scripts only. No `.xcodeproj`, no Xcode GUI.
- Ship a Developer ID signed and notarized `.app`.

## Non-goals

- Menu bar appearance changes (tint, shadow, border, shape).
- Menu bar item search or spotlight.
- Custom icons or profiles.
- Per-display rules.
- Global hotkeys (not in v1).
- Item rearrangement. Ellipsis never moves an item.
- Hiding one item of an app while another item of the same app stays visible. macOS 27 cannot do this (see "How it hides").
- macOS 26 or earlier.

## Definitions

| Term | Meaning |
|---|---|
| Item | One menu bar item from any app. |
| App | The owner of one or more items, identified by its bundle identifier. |
| Hidden set | Apps that Ellipsis hides until you click the Ellipsis icon. |
| Always-hidden set | Apps that Ellipsis hides until you Option+click the Ellipsis icon. |
| Restriction | The macOS 27 assessment-mode allow-list that Ellipsis holds while it hides apps. |
| Ellipsis icon | The clickable `NSStatusItem` that Ellipsis owns. Shows `…` or `‹`. |

## How it hides

macOS 27 moved menu bar layout into a system process, `MenuBarAgent`. The old method, a status item with a length of 10,000 points, no longer works. `MenuBarAgent` places a wide item only while it fits. It draws items that do not fit on top of the wide item. It never pushes an item off-screen. The Phase 0 spike proved this on a display without a notch. See `docs/phase0.md`.

Ellipsis uses the menu bar half of macOS assessment mode instead. This is the mechanism behind `AEAssessmentConfiguration.allowedMenuBarItems` (public, macOS 27). The public API needs an Apple-approved entitlement and locks the whole machine. The private framework `MenuBarClientCore` exposes only the menu bar part:

```
MBAssessmentModeConfiguration(allowedSystemItems: [NSNumber], allowedBundleIdentifiers: [String])
MBAssessmentModeAssertion.activate(withConfiguration:completionHandler:)
MBAssessmentModeAssertion.invalidate()
```

While an assertion is active, `MenuBarAgent` shows only the apps and system items in the allow-list. Ellipsis puts every app except the hidden ones in the allow-list. Ellipsis puts every system item code (integers 0 to 40) in the allow-list. No permission is necessary. Bartender 7 and Thaw 3 use the same mechanism.

Known limits of this mechanism:

- Granularity is one app, not one item. If an app has two items, both hide together.
- Focus and the camera/microphone indicator are hidden while a restriction is active. No system item code brings them back.
- The framework is private. Ellipsis loads it with `dlopen` and checks that the classes exist at launch. If they do not exist, Ellipsis shows an alert and quits.
- The `allowedSystemItems` codes are undocumented. Code 2 is the clock, code 6 is Wi-Fi, code 8 is Control Center.
- `MenuBarAgent` matches the allow-list only against apps that run from `/Applications`. An app that runs from another folder is always hidden while a restriction is active. This includes Ellipsis itself. The Ellipsis icon disappears if Ellipsis runs from a build folder.

Ellipsis releases the restriction when it shows the hidden set. Ellipsis holds a restriction that hides only the always-hidden set when it shows the hidden set with a normal click.

## Features

### F1: Hide and show the hidden set

- The Ellipsis icon shows `…` when the hidden set is hidden. It shows `‹` when the set is shown.
- Click the icon to toggle the hidden set.
- The state persists across restarts.

### F2: Always-hidden set

- Apps in the always-hidden set stay hidden after a normal click.
- Option+click on the Ellipsis icon shows both sets.
- The Settings window has a switch to enable or disable this set. Default: enabled.

### F3: Auto-rehide

Ellipsis rehides the hidden set when one of these conditions is true and the related setting is on:

- Timeout. A timer starts when the set is shown. Default: 15 seconds. Range: 1–300 seconds. Off is permitted.
- Click outside. The user clicks anywhere that is not the menu bar.
- Focus change. The frontmost app changes or the active Space changes.

Each condition has its own switch in Settings. Defaults: timeout on, click outside on, focus change off.

Ellipsis does not rehide while a menu from a shown item is open.

### F4: Settings window

A SwiftUI window with these controls:

- Launch at login (`SMAppService`).
- Hidden set: a list of running apps with a checkbox per app. Ellipsis lists apps with a `.regular` or `.accessory` activation policy.
- Always-hidden set: the same list, and a switch to enable the set.
- Auto-rehide: three switches and the timeout value.
- Version number and a quit button.

Open the window from a right-click menu on the Ellipsis icon. The same menu has "Show always-hidden items", "Settings…", and "Quit".

### F5: App shape

- Menu bar only. `LSUIElement` is true. No Dock icon.
- Minimum macOS: 27.0.
- Swift 6 language mode, strict concurrency.
- Persist settings in `UserDefaults`.

## Build and distribution

- `Package.swift` with one executable target. No external dependencies.
- `scripts/bundle.sh` assembles `build/Ellipsis.app` from the SwiftPM binary, `Info.plist`, entitlements and the icon.
- `scripts/sign.sh` signs with the Developer ID Application certificate and hardened runtime.
- `scripts/notarize.sh` submits the app with `notarytool`, waits, and staples the ticket.
- `scripts/release.sh` runs the three scripts above and produces a `.zip` or `.dmg`.
- Signing identity and Apple ID come from environment variables. Never commit them.

## Acceptance criteria

1. A fresh install on macOS 27 shows the Ellipsis icon. macOS shows no permission prompt.
2. Add an app to the hidden set. Its items disappear. Click the icon. The items return. Click again. The items disappear.
3. Quit and relaunch. The hidden state and the sets are unchanged.
4. Add an app to the always-hidden set. It stays hidden after a normal click. Option+click shows it.
5. Show the set, wait for the timeout. The set hides itself.
6. Show the set, click on the desktop. The set hides itself.
7. Show the set, open the menu of a shown item. The set does not hide while the menu is open.
8. While the hidden set is hidden, click the clock. Notification Center opens.
9. Quit Ellipsis. Every item returns.
10. `spctl --assess` and `stapler validate` pass on the release build.
11. `swift build` and all scripts run from a terminal with no Xcode project.

## Open risks

- Private API. A macOS 27 point release can rename or remove the `MBAssessmentMode*` classes. Ellipsis checks for them at launch.
- The `/Applications` rule comes from a test on one machine. Other folders that LaunchServices registers, such as `~/Applications`, are not tested.
- Clock click under a restriction is not tested yet (criterion 8). Bartender 7 releases its restriction around a clock click. If the click fails, Ellipsis must do the same with a global mouse monitor.
- If Ellipsis crashes, `MenuBarAgent` drops the restriction when the XPC connection closes. This needs a test.
- Global mouse monitors (`NSEvent.addGlobalMonitorForEvents`) for click-outside detection work without Accessibility permission for mouse events. If macOS 27 changes this, F3 "click outside" needs Accessibility permission and an onboarding step.
