# Phase 7 record — driving the app in a Tart guest

Date: 2026-09-18. Host: macOS 27.0 (26A428), M4 Max. Guest: `ghcr.io/cirruslabs/macos-golden-gate-base:latest`, macOS 27.0 (26A5416b), 4 CPUs, 8 GB, one 1024×768 virtual display, no notch.

## Result

Every step of the loop works over `ssh` with no manual setup in the guest. Tart is the test host. See `docs/plan.md`, Phase 7.

## What we tested

A probe binary (`CGEvent` clicks, `MenuBarLayout` over Accessibility, `screencapture`) copied into the guest with `scp` and run with `ssh`.

| Question | Answer |
|---|---|
| Can a process started by `sshd` post `CGEvent`s to the auto-login session? | Yes, with `CGEvent.post(tap: .cghidEventTap)`. No `launchctl asuser`. A click on the fixture's item opens its menu; a click on "Mark" runs the action. |
| Which process holds the grants? | The image grants Accessibility, Full Disk Access and Apple Events to `/usr/libexec/sshd-keygen-wrapper`. `AXIsProcessTrusted()` is true in any `ssh` command. Nothing to grant by hand. |
| Does `MenuBarAgent` hide an app in `/Applications` under a restriction? | Yes. With `hiddenBundleIdentifiers` set to the fixture, its item leaves the layout at launch. A click on the icon brings it back; the next click hides it. Same as on the host. |
| Does `screencapture` over `ssh` return the screen? | Yes, at 2× (2048×1536 for the 1024×768 display). |

## Also found

- SIP is disabled in the image (`csrutil status`), so the TCC database is writable if another grant is ever needed.
- `tart set --display 1440x900` sets the maximum; the guest boots at 1024×768.
- The icon moves when the set shows (from 766 to 696 points with one 70-point item), so a test reads the layout before every click. A click at the old position lands on the shown item.
- The 15 s rehide timeout runs during a test. A test either sets `rehideOnTimeout` off through `defaults write` or expects it.
- A click on the desktop shows the widgets on macOS 27. It is still "outside" for the rehide.
- The guest is a beta build (26A5416b); the host is a release build. Nothing differed in what we tested.
