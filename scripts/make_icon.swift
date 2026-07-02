// Renders the Pasties app icon from Icon.png, full-bleed onto an opaque navy
// square (sampled from the art) so it fills the macOS icon tile edge-to-edge.
// macOS rounds the corners itself; filling the tile means no dark backing
// tile shows through behind the art.
// Usage: swift make_icon.swift <source-png> <output-iconset-dir>
import AppKit

let args = CommandLine.arguments
let srcPath = args.count > 1 ? args[1] : "Icon.png"
let outDir  = args.count > 2 ? args[2] : "icon.iconset"

guard let src = NSImage(contentsOfFile: srcPath),
      let tiff0 = src.tiffRepresentation,
      let srcRep = NSBitmapImageRep(data: tiff0) else {
    FileHandle.standardError.write("cannot load \(srcPath)\n".data(using: .utf8)!)
    exit(1)
}
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// Sample the background navy from a point inside the rounded square but away
// from the (white) artwork — top edge, horizontally centered.
let bg: NSColor = {
    let x = srcRep.pixelsWide / 2
    let y = srcRep.pixelsHigh / 20   // ~5% down from the top
    return srcRep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) ?? NSColor(red: 0.078, green: 0.16, blue: 0.32, alpha: 1)
}()

func render(px: Int, name: String) {
    let img = NSImage(size: NSSize(width: px, height: px))
    img.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    let full = NSRect(x: 0, y: 0, width: px, height: px)

    // Full-bleed rounded square at the macOS corner radius (~22.37% of size).
    // Clip to it, fill navy so the shape is solid edge-to-edge, then draw the
    // art on top. No transparent margin → no dark tile shows behind it.
    let radius = CGFloat(px) * 0.2237
    let shape = NSBezierPath(roundedRect: full, xRadius: radius, yRadius: radius)
    shape.addClip()
    bg.setFill()
    full.fill()
    src.draw(in: full, from: .zero, operation: .sourceOver, fraction: 1.0)
    img.unlockFocus()

    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: "\(outDir)/\(name).png"))
}

let sizes: [(Int, String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x"),
]
for (px, name) in sizes { render(px: px, name: name) }
print("Icon rendered from \(srcPath) → \(outDir) (full-bleed, bg \(bg))")
