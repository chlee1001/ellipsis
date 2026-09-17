// Draws Resources/AppIcon.png, the source art for the app icon: three dots on
// a dark rounded square, in the macOS icon grid (the shape fills 824 of 1024
// points, so the system does not have to inset it).
//
//   swiftc -O -o build/iconrender scripts/make-icon-art.swift
//   build/iconrender Resources/AppIcon.png
//   scripts/make-icon.sh
import AppKit

let side: CGFloat = 1024
let outPath = CommandLine.arguments[1]

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let inset = (side - 824) / 2
let square = NSRect(x: inset, y: inset, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: square, xRadius: 185, yRadius: 185)

let top = NSColor(srgbRed: 0x3A/255, green: 0x3A/255, blue: 0x40/255, alpha: 1)
let bottom = NSColor(srgbRed: 0x1C/255, green: 0x1C/255, blue: 0x21/255, alpha: 1)
NSGradient(starting: top, ending: bottom)!.draw(in: shape, angle: -90)

// Three dots, the Ellipsis glyph, centered on the square.
let radius: CGFloat = 62
let gap: CGFloat = 150
NSColor.white.setFill()
for i in -1...1 {
    let center = NSPoint(x: square.midX + CGFloat(i) * gap, y: square.midY)
    NSBezierPath(ovalIn: NSRect(
        x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2
    )).fill()
}

NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: outPath))
