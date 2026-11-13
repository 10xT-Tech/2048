// Draws the app icon: App/Assets.xcassets/AppIcon.appiconset/AppIcon.png (1024×1024).
// Same language as Gist It's icon — a thin white line glyph on black: a 2×2 grid of rounded tiles
// (one solid — the merge), centred, no lettering.
// Run from the repo root:  swift tools/make_icon.swift
import AppKit

let side: CGFloat = 1024
let stroke: CGFloat = 32          // Gist It's mic glyph line weight at 1024
// Opaque RGB (App Store icons must not carry alpha).
let ctx = CGContext(data: nil, width: Int(side), height: Int(side), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

// Flip to top-left origin.
ctx.translateBy(x: 0, y: side)
ctx.scaleBy(x: 1, y: -1)

ctx.setFillColor(NSColor.black.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))

// Glyph: 2×2 tiles.
let tile: CGFloat = 236
let gap: CGFloat = 52
let grid = tile * 2 + gap
let originX = (side - grid) / 2
let originY = (side - grid) / 2
let radius: CGFloat = 52
ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setFillColor(NSColor.white.cgColor)
ctx.setLineWidth(stroke)
for row in 0..<2 {
    for col in 0..<2 {
        let rect = CGRect(x: originX + CGFloat(col) * (tile + gap), y: originY + CGFloat(row) * (tile + gap),
                          width: tile, height: tile)
        if row == 0 && col == 1 {
            ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            ctx.fillPath()
        } else {
            let inset = rect.insetBy(dx: stroke / 2, dy: stroke / 2)
            ctx.addPath(CGPath(roundedRect: inset, cornerWidth: radius - stroke / 2,
                               cornerHeight: radius - stroke / 2, transform: nil))
            ctx.strokePath()
        }
    }
}

NSGraphicsContext.restoreGraphicsState()
let url = URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: url)
print("wrote", url.path)
