# Development

## Build from source

You need Xcode Command Line Tools with Swift 6.4. No Xcode project is necessary.

```sh
mise run build
mise run test
mise run run
```

`mise run run` bundles a debug build as `EllipsisDev.app` with the identifier `au.ronny.EllipsisDev`, signs it with your Developer ID (ad hoc without one), copies it to `/Applications` and opens it. The Developer ID keeps the signature stable across builds, so the Accessibility grant for the debug build survives a rebuild. The debug build has its own settings and its own row in the Accessibility list, so it runs next to a release `Ellipsis.app`. Without mise, use `swift build`, `swift test` and `scripts/run.sh`.

## Make a release

1. Make sure that a "Developer ID Application" identity is in the login keychain.
2. Create a notarytool profile once:
   ```sh
   xcrun notarytool store-credentials ellipsis \
     --apple-id you@example.com --team-id TEAMID --password app-specific-password
   ```
3. Run `mise run release X.Y.Z`. It tags the parent of `@` as `vX.Y.Z`, pushes the tag, and writes `build/Ellipsis-X.Y.Z.zip`.

`scripts/release.sh X.Y.Z` does the build, sign, notarize and zip steps without the tag.

`DEVELOPER_ID` selects a different signing identity. `NOTARY_PROFILE` selects a different notarytool profile. The scripts are `bundle.sh`, `sign.sh`, `notarize.sh`, `release.sh` and `make-icon.sh`. Each one runs on its own.

## Documentation

- `docs/spec.md`: what Ellipsis does.
- `docs/plan.md`: how it is built, phase by phase.
- `docs/phase0.md`: what was tried against `MenuBarAgent`, and what worked.
- `docs/testing.md`: the manual test checklist.

