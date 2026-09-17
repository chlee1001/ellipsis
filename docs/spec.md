# Ellipsis — specification

Ellipsis is a macOS menu bar item manager. It hides and shows items on the menu bar. It is a stripped-down version of [Ice](https://github.com/jordanbaird/Ice) for macOS 27 (Golden Gate).

## Goals

- Hide and show menu bar items with one click.
- Keep an "always hidden" section for items that you never want to see.
- Rehide the items automatically after a timeout or after a click outside the menu bar.
- Build with SwiftPM and shell scripts only. No `.xcodeproj`, no Xcode GUI.
- Ship a Developer ID signed and notarized `.app`.

## Non-goals

- Menu bar appearance changes (tint, shadow, border, shape).
- Menu bar item search or spotlight.
- Custom icons or profiles.
- Per-app or per-display rules.
- Global hotkeys (not in v1).
- Programmatic item rearrangement. The user moves items with Cmd+drag, as macOS already permits.

## Definitions

| Term | Meaning |
|---|---|
| Item | One `NSStatusItem` from any app on the menu bar. |
| Divider | An `NSStatusItem` that Ellipsis owns. It marks the border of a section. |
| Visible section | Items to the right of the hidden divider. Always shown. |
| Hidden section | Items between the hidden divider and the always-hidden divider. Shown on demand. |
| Always-hidden section | Items to the left of the always-hidden divider. Shown only when the user asks for them. |
| Ellipsis icon | The clickable `NSStatusItem` at the right end of the sections. Shows `…` or `‹`. |

Menu bar layout, from left to right:

```
[always-hidden items] | [hidden items] | [visible items] [Ellipsis icon]
                      ^                ^
       always-hidden divider     hidden divider
```

## How it hides

A divider is an `NSStatusItem`. To hide the items to its left, Ellipsis sets the divider length to a very large value (10,000 points). macOS then pushes every item to the left of the divider off the left edge of the screen. To show them again, Ellipsis restores the divider length to its normal width.

This method needs no Accessibility or Screen Recording permission. Ice and Hidden Bar use the same method.

On a MacBook with a notch, the pushed items can stop under the notch. This is acceptable for v1.

## Features

### F1: Hide and show the hidden section

- The Ellipsis icon shows `…` when the hidden section is hidden. It shows `‹` when the section is shown.
- Click the icon to toggle the hidden section.
- The state persists across restarts.

### F2: Always-hidden section

- A second divider marks the always-hidden section. Its normal length is zero, so it is invisible.
- Option+click on the Ellipsis icon shows both sections. The always-hidden divider becomes visible so the user can Cmd+drag items across it.
- The Settings window has a switch to enable or disable this section. Default: enabled.

### F3: Auto-rehide

Ellipsis rehides the hidden section when one of these conditions is true and the related setting is on:

- Timeout. A timer starts when the section is shown. Default: 15 seconds. Range: 1–300 seconds. Off is permitted.
- Click outside. The user clicks anywhere that is not the menu bar.
- Focus change. The frontmost app changes or the active Space changes.

Each condition has its own switch in Settings. Defaults: timeout on, click outside on, focus change off.

Ellipsis does not rehide while a menu from a hidden item is open.

### F4: Settings window

A SwiftUI window with these controls:

- Launch at login (`SMAppService`).
- Always-hidden section: on or off.
- Auto-rehide: three switches and the timeout value.
- A short instruction: "Hold Cmd and drag items across the divider to move them."
- Version number and a quit button.

Open the window from a right-click menu on the Ellipsis icon. The same menu has "Show always-hidden items", "Settings…", and "Quit".

### F5: App shape

- Menu bar only. `LSUIElement` is true. No Dock icon.
- Minimum macOS: 27.0.
- Swift 6 language mode, strict concurrency.
- Persist settings in `UserDefaults`. Divider positions persist through `NSStatusItem.autosaveName`.

## Build and distribution

- `Package.swift` with one executable target. No external dependencies.
- `scripts/bundle.sh` assembles `build/Ellipsis.app` from the SwiftPM binary, `Info.plist`, entitlements and the icon.
- `scripts/sign.sh` signs with the Developer ID Application certificate and hardened runtime.
- `scripts/notarize.sh` submits the app with `notarytool`, waits, and staples the ticket.
- `scripts/release.sh` runs the three scripts above and produces a `.zip` or `.dmg`.
- Signing identity and Apple ID come from environment variables. Never commit them.

## Acceptance criteria

1. A fresh install on macOS 27 shows the Ellipsis icon and one visible divider.
2. Cmd+drag an item to the left of the divider. Click the icon. The item disappears. Click again. The item returns.
3. Quit and relaunch. The hidden state and item positions are unchanged.
4. Option+click shows the always-hidden divider. Cmd+drag an item past it. Release Option. The item is not visible after a normal click.
5. Show the section, wait for the timeout. The section hides itself.
6. Show the section, click on the desktop. The section hides itself.
7. Show the section, open the menu of a hidden item. The section does not hide while the menu is open.
8. `spctl --assess` and `stapler validate` pass on the release build.
9. `swift build` and all scripts run from a terminal with no Xcode project.

## Open risks

- macOS 27 can change `NSStatusItem` behavior. Ice broke on macOS 26 (Tahoe) and the Thaw fork carries the fixes. The first task in the plan is a spike that proves the large-length method works on 27.
- Global mouse monitors (`NSEvent.addGlobalMonitorForEvents`) for click-outside detection work without Accessibility permission for mouse events. If macOS 27 changes this, F3 "click outside" needs Accessibility permission and an onboarding step.
