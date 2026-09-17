# Credits

Ellipsis itself is under the Apache License 2.0. See [LICENSE](LICENSE).

## Ships inside the application

Nothing from a third party. The app icon is three circles on a gradient, drawn
by `scripts/make-icon-art.swift`. The menu bar icons are the SF Symbols
`ellipsis` and `chevron.left`, used under the Apple SDK licence.

## Apple frameworks

AppKit, SwiftUI, Observation and ServiceManagement are used under the Apple SDK
licence that comes with Xcode. `MenuBarClientCore` is a private Apple framework
that Ellipsis loads at run time with `dlopen`. Nothing from it is redistributed.
