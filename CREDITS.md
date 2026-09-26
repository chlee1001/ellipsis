# Credits

Ellipsis itself is under the Apache License 2.0. See [LICENSE](LICENSE).

## Origin and modifications

This repository is based on [ronny/ellipsis](https://github.com/ronny/ellipsis)
by Ronny Haryanto. The original Apache 2.0 license and copyright notice
remain in [LICENSE](LICENSE). Chaehyeon Lee modified the floating bar to pin
menu bar items and changed the pin fit and rehide behavior in 2026. Modified
upstream files carry individual change notices.

The following lists other work that ships inside the app, and what was read
to learn how macOS 27 hides menu bar items.

## Ships inside the application

Apart from the original Ellipsis source noted above, no third-party code or
assets were added. The app icon is three circles on a gradient, drawn
by `scripts/make-icon-art.swift`. The menu bar icons are the SF Symbols
`ellipsis` and `chevron.left`, used under the Apple SDK licence.

## Read while writing this, but not shipped

None of the following is distributed with Ellipsis. **No code was copied.**
They were read to learn what `MenuBarAgent` does on macOS 27, which is a fact
about the operating system, not a work of any of these projects.

### Ice

- Upstream: [jordanbaird/Ice](https://github.com/jordanbaird/Ice)
- Licence: **GPL-3.0**

Read to learn the divider-length method (`ControlItem.swift`) and why it fails
on macOS 27 (PR 994, issue 980). Ellipsis does not use that method. Because Ice
is GPL, none of its code or assets is in this repository, including its
Ellipsis icon. See `docs/phase0.md`.

### Thaw

- Upstream: [thaw-app/Thaw](https://github.com/thaw-app/Thaw)
- Licence: see upstream

The 3.0.0 alpha release notes were read to learn about the `MenuBarAgent`
layout table and the per-app hiding limit.

### AutomaticAssessmentConfiguration

- Apple SDK headers: `allowsMenuBar`, `allowedMenuBarItems`, `AEMenuBarItem`.

The public framework that the private `MenuBarClientCore` mirrors. Read for the
system item names.

## Apple frameworks

AppKit, SwiftUI, Observation and ServiceManagement are used under the Apple SDK
licence that comes with Xcode. `MenuBarClientCore` is a private Apple framework
that Ellipsis loads at run time with `dlopen`. Nothing from it is redistributed.

## Not affiliated

Ice and Thaw are the work of their owners. Ellipsis is an independent app and
is not endorsed by any of them.
