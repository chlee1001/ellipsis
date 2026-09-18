# Development

## Build from source

You need Xcode Command Line Tools with Swift 6.4. No Xcode project is necessary.

```sh
mise run build
mise run test
mise run run
```

`mise run run` bundles a debug build as `EllipsisDev.app` with the identifier `au.ronny.EllipsisDev`, signs it with your Developer ID (ad hoc without one), copies it to `/Applications` and opens it. The Developer ID keeps the signature stable across builds, so the Accessibility grant for the debug build survives a rebuild. The debug build has its own settings and its own row in the Accessibility list, so it runs next to a release `Ellipsis.app`. `mise run install` does the same with a release build as `Ellipsis.app`, signed but not notarized. Without mise, use `swift build`, `swift test`, `scripts/run.sh` and `scripts/run.sh release`.

## VM tests

`Tests/EllipsisVMTests` drives the app in a macOS guest, so a test run never touches your own menu bar or pointer. The guest is a [Tart](https://tart.run) VM cloned from `ghcr.io/cirruslabs/macos-golden-gate-base`, on which the image already grants Accessibility to `sshd`. The tests run on the host and reach the guest over `ssh`, through `scripts/vm.sh`. Every step is in `docs/plan.md`, Phase 7, and the spike in `docs/phase7.md`.

Once:

```sh
curl -sSL https://github.com/cirruslabs/tart/releases/latest/download/tart.tar.gz | tar xz -C ~/.local/opt
ln -s ~/.local/opt/tart.app/Contents/MacOS/tart ~/.local/bin/tart
tart pull ghcr.io/cirruslabs/macos-golden-gate-base:latest   # about 40 GB
scripts/vm.sh prepare                                          # the golden VM, 20 seconds
```

The Homebrew formula for `tart` does not install on current Homebrew, hence the tarball.

To free the 40 GB the pulled image takes on the local disk, move `~/.tart/cache` to a NAS after `prepare`:

```sh
rsync -a ~/.tart/cache/ /path/on/nas/tart/cache/
rsync -a --checksum --itemize-changes ~/.tart/cache/ /path/on/nas/tart/cache/   # prints nothing when the copy is good
rm -r ~/.tart/cache
ln -s /path/on/nas/tart/cache ~/.tart/cache
```

Not `mv` or `cp`: `copyfile` spins on `lseek` for ever when it copies the sparse disk image to NFS.

Do this after `prepare`, not before: `tart pull` downloads into `~/.tart/tmp` and renames into `cache`, which fails across file systems. Keep `~/.tart/vms` local. `tart clone` is an APFS clone there, so a test run costs no space and no time; on NFS it would copy the whole image.

Then:

```sh
mise run vm-test                                # clone, install, test, delete: about two minutes
mise run vm-test -- --filter RehideTests        # one suite
```

`scripts/vm-test.sh` clones the golden VM as `ELLIPSIS_VM` (default `ellipsis-test`), copies `EllipsisDev.app`, the three fixture apps and the probe into it, grants the app Accessibility in the guest's TCC database, runs `swift test --filter EllipsisVMTests`, copies `~/screenshots` from the guest to `build/vm-screenshots`, and deletes the VM. `ELLIPSIS_VM_KEEP=1` leaves the VM running after the run. `ELLIPSIS_VM_REUSE=1` runs against a VM that is already up, which is the loop while writing a test: `scripts/vm.sh clone` once, then `ELLIPSIS_VM_REUSE=1 scripts/vm-test.sh` as often as needed, then `scripts/vm.sh delete`. `scripts/vm.sh ssh` opens a shell in the guest, and `tart run ellipsis-test --vnc` after `scripts/vm.sh stop` shows its screen.

Without `ELLIPSIS_VM` the suites skip, so `mise run test` and CI stay unit tests. The rows of `docs/testing.md` marked `vm` have a test. The guest has no notch.

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

## A second machine

The release credentials live in the login keychain of the machine that made the first release. To release from another machine, move three things over. `gh auth login` is the fourth, and needs no file.

On the release machine:

1. Certificates with their private keys: Xcode › Settings › Accounts › your Apple ID › ⚙ › "Export Apple ID and Code Signing Assets…" writes a `.developerprofile` with every certificate and key, the Developer ID Application identity among them. Keychain Access › My Certificates › right-click the identity › Export writes a `.p12` with only that one.
2. The Sparkle key: `mise run sparkle-keys -- -x sparkle.key`.
3. The app-specific password for notarytool cannot be exported. Use the one you have, or make a new one at appleid.apple.com.

On the new machine:

1. Open the `.developerprofile` (Xcode imports it) or the `.p12`. `security find-identity -v -p codesigning` then lists "Developer ID Application".
2. `mise run sparkle-keys -- -f sparkle.key`, then erase the file. `mise run sparkle-keys -- -p` must print the `SUPublicEDKey` in `Resources/Info.plist`; a different key strands every installed copy (see "The update key").
3. `xcrun notarytool store-credentials ellipsis --apple-id you@example.com --team-id TEAMID --password <app-specific-password>`.

Without the Developer ID identity, `scripts/bundle.sh` signs a debug build with an Apple Development identity if there is one, else ad hoc. Only a certificate keeps the Accessibility grant across rebuilds. A new Developer ID Application certificate can be made in Xcode › Settings › Accounts › Manage Certificates (account holder only, five per team) and signs future releases as well as the old one; only the Sparkle key has to be the original.

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
- `docs/phase7.md`: what was tried in a Tart guest, and what worked.
- `docs/testing.md`: the test checklist, VM and manual.

