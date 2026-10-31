// Draws the iOS app icon: a light bulb in line, its filament lit in the accent blue, the contact tip in white.
// Writes TuyaLights/Assets.xcassets/AppIcon.appiconset/icon-1024.png.  Run: swift scripts/icon.swift
import AppKit
import SwiftUI

let accent = Color(red: 0x34 / 255, green: 0x6b / 255, blue: 0xf1 / 255)

struct Icon: View {
    var body: some View {
        // iOS: full-bleed opaque square, the system masks the corners.
        ZStack {
            LinearGradient(colors: [Color(white: 0.09), Color(white: 0.02)], startPoint: .top, endPoint: .bottom)
            Canvas { ctx, _ in
                let line = GraphicsContext.Shading.color(.white.opacity(0.55))
                let style = StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round)
                let c = CGPoint(x: 512, y: 420), r: CGFloat = 200
                // Globe, neck and screw base as one path, so overlapping strokes don't double the white.
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: 428, y: 680))
                    p.addCurve(to: CGPoint(x: c.x - r * 0.707, y: c.y + r * 0.707),
                               control1: CGPoint(x: 428, y: 630), control2: CGPoint(x: 395, y: 600))
                    p.addArc(center: c, radius: r, startAngle: .degrees(135), endAngle: .degrees(45), clockwise: false)
                    p.addCurve(to: CGPoint(x: 596, y: 680),
                               control1: CGPoint(x: 629, y: 600), control2: CGPoint(x: 596, y: 630))
                    p.addRoundedRect(in: CGRect(x: 428, y: 680, width: 168, height: 96), cornerSize: CGSize(width: 14, height: 14))
                    p.move(to: CGPoint(x: 428, y: 728)); p.addLine(to: CGPoint(x: 596, y: 728))
                }, with: line, style: style)
                // The lit filament.
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: 476, y: 610)); p.addLine(to: CGPoint(x: 470, y: 470))
                    p.addArc(center: CGPoint(x: 512, y: 470), radius: 42, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                    p.addLine(to: CGPoint(x: 548, y: 610))
                }, with: .color(accent), style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round))
                // Contact tip.
                ctx.fill(Path(roundedRect: CGRect(x: 470, y: 792, width: 84, height: 34), cornerRadius: 17), with: .color(.white))
            }
        }
        .frame(width: 1024, height: 1024)
    }
}

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let out = root.appending(path: "TuyaLights/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
let image = MainActor.assumeIsolated { ImageRenderer(content: Icon()).cgImage! }
// Redraw without an alpha channel: the App Store rejects icons with alpha.
let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
let flat = ctx.makeImage()!
assert(flat.width == 1024 && flat.height == 1024 && flat.alphaInfo == .noneSkipLast)
try NSBitmapImageRep(cgImage: flat).representation(using: .png, properties: [:])!.write(to: out)
print(out.path)
