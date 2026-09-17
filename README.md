# Ellipsis

Ellipsis hides selected menu bar items on macOS 27. Click its icon to show them. Click again, or wait, to hide them again.

## Requirements

- macOS 27.0 or later.
- Ellipsis must run from `/Applications`. `MenuBarAgent` matches the allow-list against apps in that folder only. A copy in any other folder hides its own icon.
- No permissions. Ellipsis does not ask for Accessibility or Screen Recording.

## Install a release

1. Download `Ellipsis-X.Y.Z.zip` from [GitHub Releases](../../releases).
2. Open the zip. Move `Ellipsis.app` to `/Applications`.
3. Open Ellipsis. The `…` icon appears in the menu bar.
4. Right-click the icon. Select "Settings…". Put apps in the hidden set.

## Limits

- Private API. Ellipsis loads `MenuBarClientCore.framework` and uses its `MBAssessmentMode` classes. A macOS update can rename or remove them. Ellipsis checks for the classes at launch and shows an alert if they are missing.
- Focus and the camera/microphone indicator are hidden while any set is hidden. No setting brings them back. This is a limit of the API.
- The hidden sets hold whole apps, not single items. An app with two menu bar items hides both.
- The app pickers in Settings list every running app, not only apps with a menu bar item. macOS 27 gives no way to tell them apart without the Accessibility permission.

## Alternatives

- [Ice](https://github.com/jordanbaird/Ice), doesn't work in macOS 27 at the time of writing.
- [Thaw](https://github.com/thaw-app/Thaw), doesn't work in macOS 27 at the time of writing.
- [Bartender 7](https://www.macbartender.com/bartender7)

## Development

See [docs/development.md](docs/development.md) for how to build, test and release.

## License

Ellipsis is under the Apache License 2.0. See [LICENSE](LICENSE).
