# Manual test checklist

Run `scripts/run.sh` first. Set the sets in Settings › Hidden and Settings › Always Hidden.

Numbers match the acceptance criteria in `docs/spec.md`.

| # | Steps | Expect | Result |
|---|---|---|---|
| 1 | Fresh install, launch | Icon shows `…`. One Ellipsis dialog offers Accessibility. No macOS prompt. | |
| 1a | Dialog: "Not Now". Quit. Relaunch. | No dialog. Settings › General shows "Grant Permission…". | |
| 1b | Settings: "Grant Permission…", then turn Ellipsis on in System Settings › Accessibility. | Settings shows "Granted" without a relaunch. Hidden tab lists only apps with a menu bar item. | |
| 2 | Put an app in the hidden set. Click the icon. Click again. | Items hide, show (`‹`), hide (`…`). | |
| 3 | Show the set. Quit. Relaunch. | Set is still shown. Sets are unchanged. | |
| 4 | Put an app in the always-hidden set. Click. Option+click. | Normal click keeps it hidden. Option+click shows it. | |
| 4a | Right-click, "Show always-hidden items". | Both sets show. Menu item gets a checkmark. | |
| 4b | Settings: turn off "Keep an always-hidden set". | Always-hidden apps appear at once. | |
| 5 | Show the set. Wait for the timeout (default 15 s). | Set hides. | Pass |
| 5a | Settings: set the timeout to 3 s while the set is shown. | Set hides 3 s later. | Pass |
| 5b | Settings: turn "After a timeout" off. Show the set. Wait. | Set stays. | Pass |
| 6 | Show the set. Click the desktop. | Set hides. | Pass |
| 6a | Show the set. Click another item in the menu bar. | Set stays. | Pass |
| 6b | Settings: turn "When the front app or Space changes" on. Show the set. Cmd+Tab to another app. | Set hides. | Pass |
| 6c | Same setting on. Show the set. Right-click, "Settings…". | Set stays. Ellipsis coming to the front is not a focus change. | Pass |
| 7 | Show the set. Open the menu of a shown item. Wait past the timeout. | Set stays while the menu is open. Hides right after the menu closes. | Pass |
| 7a | Show the set. Open the menu of a shown item. Pick a menu item. | Menu action runs. Set hides. | Pass |
| 8 | While the set is hidden, move the pointer to the clock. Click. Move away. | Hidden items show near the clock. Notification Center opens. Items hide again after 0.5 s. | Pass |
| 8a | Without Accessibility: General, "Click the Clock…", click the left edge of the clock. | The width becomes the distance to the right edge plus 30. "Reset" returns 300. | Pass |
| 8b | With Accessibility: open General. | "N points, measured". Hidden items show over the clock, not over Control Center. | |
| 9 | Quit from the right-click menu. | Every item returns. | |
| 9a | `kill -9` Ellipsis. | Every item returns. | |
| S1 | Settings › Hidden: check an app. | Its items hide at once. | Pass |
| S2 | Check the same app under Always Hidden. | It leaves the Hidden list. Items stay hidden after a normal click. | Pass |
| S3 | Check an app, quit that app. | It stays in the list, marked "Not running". Uncheck it. It leaves the list. | |
| S4 | Launch another app while Settings is open. | It appears in both lists. | |
| S5 | General: turn on "Launch at login". Open System Settings › Login Items. | Ellipsis is listed. Turn it off there. The switch in Ellipsis turns off when the window reopens. | |
| S6 | General: "Quit Ellipsis". | Every item returns. | |
| S7 | General: "Export…", save. Open the file. | A plist with the sets and the rehide options. No `isHiddenSetShown`. | |
| S8 | Change a set. General: "Import…", pick the file from S7. | The set returns to the exported one at once. Items hide or show to match. | |
| S9 | "Import…", pick a plist that is not from Ellipsis. | An alert: "The file has no Ellipsis settings." Settings unchanged. | |
| 10 | Release build: `spctl --assess`, `stapler validate`. | Both pass. | Phase 5 |
| 11 | Clean checkout: `swift build`, every script. | No Xcode project needed. | Phase 5 |
