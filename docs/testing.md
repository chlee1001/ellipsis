# Manual test checklist

Run `scripts/run.sh` first. Set the sets with `defaults` until the Settings window has an app picker (Phase 4):

```
defaults write to.haryan.Ellipsis hiddenBundleIdentifiers -array com.example.one
defaults write to.haryan.Ellipsis alwaysHiddenBundleIdentifiers -array com.example.two
```

Relaunch after a `defaults write`. Ellipsis reads the sets at launch only.

Numbers match the acceptance criteria in `docs/spec.md`.

| # | Steps | Expect | Result |
|---|---|---|---|
| 1 | Fresh install, launch | Icon shows `…`. No permission prompt. | |
| 2 | Put an app in the hidden set. Click the icon. Click again. | Items hide, show (`‹`), hide (`…`). | |
| 3 | Show the set. Quit. Relaunch. | Set is still shown. Sets are unchanged. | |
| 4 | Put an app in the always-hidden set. Click. Option+click. | Normal click keeps it hidden. Option+click shows it. | |
| 4a | Right-click, "Show always-hidden items". | Both sets show. Menu item gets a checkmark. | |
| 4b | Settings: turn off "Keep an always-hidden set". | Always-hidden apps appear at once. | |
| 5 | Show the set. Wait for the timeout. | Set hides. | Phase 3 |
| 6 | Show the set. Click the desktop. | Set hides. | Phase 3 |
| 7 | Show the set. Open the menu of a shown item. Wait. | Set stays while the menu is open. | Phase 3 |
| 8 | While the set is hidden, move the pointer to the clock. Click. Move away. | Hidden items show near the clock. Notification Center opens. Items hide again after 0.5 s. | |
| 9 | Quit from the right-click menu. | Every item returns. | |
| 9a | `kill -9` Ellipsis. | Every item returns. | |
| 10 | Release build: `spctl --assess`, `stapler validate`. | Both pass. | Phase 5 |
| 11 | Clean checkout: `swift build`, every script. | No Xcode project needed. | Phase 5 |
