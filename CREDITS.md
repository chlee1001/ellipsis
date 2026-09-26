# Credits

Ellipsis itself is under the Apache License 2.0. See [LICENSE](LICENSE).

## Origin and modifications

This repository is based on [ronny/ellipsis](https://github.com/ronny/ellipsis)
by Ronny Haryanto. The original Apache 2.0 license and copyright notice
remain in [LICENSE](LICENSE). Chaehyeon Lee modified the floating bar to pin
menu bar items and changed the pin fit and rehide behavior in 2026. Modified
upstream files carry individual change notices.

## Ships inside the application

Apart from the original Ellipsis source noted above, no third-party code or
assets were added. The app icon is three circles on a gradient, drawn
by `scripts/make-icon-art.swift`. The menu bar icons are the SF Symbols
`ellipsis` and `chevron.left`, used under the Apple SDK licence.

## Apple frameworks

AppKit, SwiftUI, Observation and ServiceManagement are used under the Apple SDK
licence that comes with Xcode. `MenuBarClientCore` is a private Apple framework
that Ellipsis loads at run time with `dlopen`. Nothing from it is redistributed.
