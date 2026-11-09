#!/usr/bin/env swift
// Renders the app icon at every size macOS needs.
// Usage: swift scripts/generate-icon.swift "News Digest/Assets.xcassets/AppIcon.appiconset"
import AppKit

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func render(pixels: Int) -> Data {
    let size = CGFloat(pixels)
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        // macOS icon grid: artwork occupies ~82% of the canvas, with a soft shadow.
        let inset = size * 0.09
        let body = rect.insetBy(dx: inset, dy: inset)
        let radius = body.width * 0.2237
        let path = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = size * 0.025
        shadow.shadowOffset = NSSize(width: 0, height: -size * 0.012)
        shadow.set()
        NSColor.black.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()

        // Deep blue → violet gradient background
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        NSGradient(colors: [
            NSColor(srgbRed: 0.10, green: 0.16, blue: 0.42, alpha: 1),
            NSColor(srgbRed: 0.33, green: 0.20, blue: 0.68, alpha: 1)
        ])!.draw(in: body, angle: -55)

        // Soft "glass" highlight across the top
        NSGradient(colors: [NSColor.white.withAlphaComponent(0.28), NSColor.white.withAlphaComponent(0)])!
            .draw(in: NSRect(x: body.minX, y: body.midY, width: body.width, height: body.height / 2), angle: -90)
        NSGraphicsContext.restoreGraphicsState()

        // Hairline border
        NSColor.white.withAlphaComponent(0.25).setStroke()
        path.lineWidth = max(1, size * 0.004)
        path.stroke()

        // Newspaper glyph
        let config = NSImage.SymbolConfiguration(pointSize: size * 0.46, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
        if let symbol = NSImage(systemSymbolName: "newspaper.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(config) {
            let s = symbol.size
            let origin = NSPoint(x: rect.midX - s.width / 2, y: rect.midY - s.height / 2)
            NSGraphicsContext.saveGraphicsState()
            let glow = NSShadow()
            glow.shadowColor = NSColor.black.withAlphaComponent(0.3)
            glow.shadowBlurRadius = size * 0.02
            glow.shadowOffset = NSSize(width: 0, height: -size * 0.01)
            glow.set()
            symbol.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
        }
        return true
    }

    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(point: Int, scale: Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
var images: [[String: String]] = []
for (point, scale) in sizes {
    let name = "icon_\(point)x\(point)@\(scale)x.png"
    try render(pixels: point * scale).write(to: URL(fileURLWithPath: outputDir).appendingPathComponent(name))
    images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(point)x\(point)"])
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
let json = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try json.write(to: URL(fileURLWithPath: outputDir).appendingPathComponent("Contents.json"))
print("Wrote \(sizes.count) icons to \(outputDir)")
