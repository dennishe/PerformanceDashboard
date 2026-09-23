import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let bounds = CGRect(x: 76, y: 76, width: 872, height: 872)
let silhouette = CGPath(roundedRect: bounds, cornerWidth: 205, cornerHeight: 205, transform: nil)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

guard CommandLine.arguments.count == 2,
      let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      ),
      let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(30, 49, 54), color(16, 27, 32)] as CFArray,
        locations: [0, 1]
      ) else {
    fatalError("Usage: swift scripts/render-icon.swift <output.png>")
}

context.addPath(silhouette)
context.clip()
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 180, y: 900),
    end: CGPoint(x: 850, y: 120),
    options: []
)

context.addPath(silhouette)
context.setStrokeColor(color(112, 148, 151, 0.32))
context.setLineWidth(9)
context.strokePath()

let center = CGPoint(x: 512, y: 513)
let radius: CGFloat = 277
context.setLineCap(.round)
context.setLineWidth(33)
context.addArc(center: center, radius: radius, startAngle: -.pi / 4, endAngle: .pi * 5 / 4, clockwise: false)
context.setStrokeColor(color(56, 79, 83))
context.strokePath()

context.addArc(center: center, radius: radius, startAngle: .pi * 5 / 4, endAngle: .pi * 2.17, clockwise: false)
context.setStrokeColor(color(103, 219, 181))
context.strokePath()

context.setStrokeColor(color(103, 219, 181))
context.setLineWidth(28)
context.setLineJoin(.round)
context.move(to: CGPoint(x: 294, y: 477))
context.addLine(to: CGPoint(x: 383, y: 477))
context.addLine(to: CGPoint(x: 434, y: 535))
context.addLine(to: CGPoint(x: 482, y: 535))
context.addLine(to: CGPoint(x: 527, y: 644))
context.addLine(to: CGPoint(x: 576, y: 425))
context.addLine(to: CGPoint(x: 625, y: 488))
context.addLine(to: CGPoint(x: 725, y: 488))
context.strokePath()

context.setFillColor(color(233, 184, 107))
context.fillEllipse(in: CGRect(x: 514, y: 631, width: 26, height: 26))

guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, UTType.png.identifier as CFString, 1, nil
      ) else {
    fatalError("Could not create icon image")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write icon image") }