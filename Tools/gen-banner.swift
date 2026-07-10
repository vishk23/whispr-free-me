// Generates the Rhapsode hero banner (1280x640 — also GitHub social-preview
// sized). Reuses the lyre-waveform mark beside a wordmark and tagline.
//   swiftc -o /tmp/gen-banner Tools/gen-banner.swift && /tmp/gen-banner
import AppKit

let width: CGFloat = 1280
let height: CGFloat = 640

let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError() }

// Field
let bg = NSGradient(colors: [
    NSColor(calibratedRed: 0.07, green: 0.06, blue: 0.20, alpha: 1),
    NSColor(calibratedRed: 0.16, green: 0.09, blue: 0.38, alpha: 1),
    NSColor(calibratedRed: 0.30, green: 0.12, blue: 0.58, alpha: 1)
])!
bg.draw(in: NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)), angle: -60)

// Faint oversized waveform across the whole banner
let faint = NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 0.05)
var wx: CGFloat = 40
let waveHeights: [CGFloat] = [90, 160, 240, 320, 420, 320, 240, 300, 380, 300, 200, 140, 200, 280, 360, 280, 180, 120, 90, 150]
for h in waveHeights {
    let bar = NSBezierPath(roundedRect: NSRect(x: wx, y: (height - h) / 2, width: 26, height: h), xRadius: 13, yRadius: 13)
    faint.setFill()
    bar.fill()
    wx += 62
}

// — Lyre mark (compact version of the app icon) —
let gold = NSColor(calibratedRed: 0.97, green: 0.78, blue: 0.26, alpha: 1)
let cx: CGFloat = 300
let scale: CGFloat = 0.62
let bowlY: CGFloat = height / 2 - 210 * scale
let topY: CGFloat = height / 2 + 268 * scale
let armStroke: CGFloat = 30
let armSpreadTop: CGFloat = 250 * scale
let armSpreadMid: CGFloat = 300 * scale

ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18,
              color: NSColor.black.withAlphaComponent(0.5).cgColor)
func armPath(_ side: CGFloat) -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: cx + side * 70 * scale, y: bowlY))
    p.curve(
        to: NSPoint(x: cx + side * armSpreadTop, y: topY),
        controlPoint1: NSPoint(x: cx + side * armSpreadMid, y: bowlY + 40 * scale),
        controlPoint2: NSPoint(x: cx + side * (armSpreadTop + 70 * scale), y: topY - 190 * scale)
    )
    p.lineWidth = armStroke
    p.lineCapStyle = .round
    return p
}
gold.setStroke()
armPath(-1).stroke()
armPath(1).stroke()

let crossbarY = topY - 78 * scale
let crossbar = NSBezierPath()
crossbar.move(to: NSPoint(x: cx - armSpreadTop - 6, y: crossbarY))
crossbar.line(to: NSPoint(x: cx + armSpreadTop + 6, y: crossbarY))
crossbar.lineWidth = armStroke - 4
crossbar.lineCapStyle = .round
crossbar.stroke()

let bowl = NSBezierPath()
bowl.appendArc(withCenter: NSPoint(x: cx, y: bowlY + 26 * scale), radius: 96 * scale,
               startAngle: 190, endAngle: 350, clockwise: false)
bowl.lineWidth = armStroke
bowl.lineCapStyle = .round
bowl.stroke()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// Waveform strings
let ivory = NSColor(calibratedRed: 0.99, green: 0.97, blue: 0.90, alpha: 1)
let stringHeights: [CGFloat] = [120, 200, 300, 380, 300, 200, 120].map { $0 * scale }
let barW: CGFloat = 30 * scale
let gap: CGFloat = 34 * scale
let total = CGFloat(stringHeights.count) * barW + CGFloat(stringHeights.count - 1) * gap
var sx = cx - total / 2
let midY = (bowlY + topY) / 2
ctx.setShadow(offset: .zero, blur: 12,
              color: NSColor(calibratedRed: 1, green: 0.95, blue: 0.75, alpha: 0.5).cgColor)
for h in stringHeights {
    let bar = NSBezierPath(roundedRect: NSRect(x: sx, y: midY - h / 2, width: barW, height: h),
                           xRadius: barW / 2, yRadius: barW / 2)
    ivory.setFill()
    bar.fill()
    sx += barW + gap
}
ctx.setShadow(offset: .zero, blur: 0, color: nil)

// — Wordmark + tagline —
let title = "Rhapsode" as NSString
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 130, weight: .bold),
    .foregroundColor: NSColor.white,
    .kern: 2.0
]
title.draw(at: NSPoint(x: 505, y: height / 2 - 20), withAttributes: titleAttrs)

let tagline = "Open-source dictation for the Mac.\nSpeaks back in your own voice." as NSString
let taglineAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 42, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.82)
]
tagline.draw(at: NSPoint(x: 510, y: height / 2 - 150), withAttributes: taglineAttrs)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError() }
try! png.write(to: URL(fileURLWithPath: "Resources/hero-banner.png"))
print("wrote Resources/hero-banner.png")
