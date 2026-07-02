// Generates a placeholder Icon.png: teal rounded square with white tally marks.
// Usage: swift scripts/make_placeholder_icon.swift Icon.png
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// Background gradient (teal)
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let gradient = NSGradient(starting: NSColor(calibratedRed: 0.07, green: 0.55, blue: 0.46, alpha: 1),
                          ending: NSColor(calibratedRed: 0.03, green: 0.38, blue: 0.32, alpha: 1))!
gradient.draw(in: rect, angle: -70)

// Four vertical tally strokes + one diagonal, in white
NSColor.white.setStroke()
let strokeWidth: CGFloat = 58
let top: CGFloat = size * 0.74
let bottom: CGFloat = size * 0.26
let xs: [CGFloat] = [0.30, 0.435, 0.57, 0.705].map { $0 * size }

for x in xs {
    let p = NSBezierPath()
    p.lineWidth = strokeWidth
    p.lineCapStyle = .round
    p.move(to: NSPoint(x: x, y: bottom))
    p.line(to: NSPoint(x: x, y: top))
    p.stroke()
}
let diag = NSBezierPath()
diag.lineWidth = strokeWidth
diag.lineCapStyle = .round
diag.move(to: NSPoint(x: size * 0.22, y: size * 0.60))
diag.line(to: NSPoint(x: size * 0.785, y: size * 0.40))
diag.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("could not render icon")
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Icon.png"
try! png.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
