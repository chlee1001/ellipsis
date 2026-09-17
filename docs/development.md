# Development

## Build from source

You need Xcode Command Line Tools with Swift 6.4. No Xcode project is necessary.

```sh
mise run build
mise run test
mise run run
```

`mise run run` bundles a debug build as `EllipsisDev.app` with the identifier `au.ronny.EllipsisDev`, signs it with your Developer ID (ad hoc without one), copies it to `/Applications` and opens it. The Developer ID keeps the signature stable across builds, so the Accessibility grant for the debug build survives a rebuild. The debug build has its own settings and its own row in the Accessibility list, so it runs next to a release `Ellipsis.app`. `mise run install` does the same with a release build as `Ellipsis.app`, signed but not notarized. Without mise, use `swift build`, `swift test`, `scripts/run.sh` and `scripts/run.sh release`.

## Make a release

1. Make sure that a "Developer ID Application" identity is in the login keychain.
2. Create a notarytool profile once:
   ```sh
   xcrun notarytool store-credentials ellipsis \
     --apple-id you@example.com --team-id TEAMID --password app-specific-password
   ```
3. Make sure that the Sparkle EdDSA key is in the login keychain. Run `mise run sparkle-keys -- -p`. If the command finds no key, see "The update key" below.
4. Make sure that `gh auth status` shows a login.
5. Run `mise run release X.Y.Z`. It tags the parent of `@` as `vX.Y.Z`, pushes the tag, writes `build/Ellipsis-X.Y.Z.zip` and `build/appcast.xml`, and creates the GitHub release with both files.

`scripts/release.sh X.Y.Z` does the build, sign, notarize, zip and appcast steps without the tag. `scripts/publish.sh X.Y.Z` (or `mise run publish X.Y.Z`) creates the GitHub release from the two files.

`DEVELOPER_ID` selects a different signing identity. `NOTARY_PROFILE` selects a different notarytool profile. The scripts are `bundle.sh`, `sign.sh`, `sign-sparkle.sh`, `notarize.sh`, `release.sh`, `publish.sh` and `make-icon.sh`. Each one runs on its own.

## Updates

Ellipsis uses [Sparkle 2](https://sparkle-project.org) from SwiftPM. `SUFeedURL` in `Resources/Info.plist` is `https://github.com/ronny/ellipsis/releases/latest/download/appcast.xml`. GitHub serves the `appcast.xml` asset of the newest release that is not a draft or a pre-release. Each release has an appcast with one item, itself, so the newest release is the only update that Sparkle sees.

`generate_appcast` signs the zip with the EdDSA key in the login keychain. `SUPublicEDKey` in `Resources/Info.plist` is the public half. An app can only install an update that this key signed.

### The update key

`mise run sparkle-keys` runs Sparkle's `generate_keys`. The key is per login keychain, not per app. One key signs every app that you ship with Sparkle.

The private key is in the login keychain of the machine that made the first release. It is not in the repository. To release from another machine, export the key with `mise run sparkle-keys -- -x sparkle.key`, and import it there with `mise run sparkle-keys -- -f sparkle.key`. Then erase the file.

If the key is lost, run `mise run sparkle-keys` for a new one and put the new public key in `Resources/Info.plist`. Apps that have the old key cannot install the next release. Users must download it by hand.

## Documentation

- `docs/spec.md`: what Ellipsis does.
- `docs/plan.md`: how it is built, phase by phase.
- `docs/phase0.md`: what was tried against `MenuBarAgent`, and what worked.
- `docs/testing.md`: the manual test checklist.

