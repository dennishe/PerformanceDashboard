import AppKit

enum RingGaugeAtlasRenderer {
    static func renderAtlas(for key: RingGaugeAtlasKey) -> RingGaugeAtlas {
        let columns = Int(ceil(sqrt(Double(RingGaugeAtlas.frameCount))))
        let rows = Int(ceil(Double(RingGaugeAtlas.frameCount) / Double(columns)))
        let frameSize = Int((RingGaugeGeometry.displayDiameter * key.scale).rounded(.up))

        guard frameSize > 0,
              let context = CGContext(
                  data: nil,
                  width: frameSize * columns,
                  height: frameSize * rows,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return fallbackAtlas()
        }

        for frameIndex in 0..<RingGaugeAtlas.frameCount {
            let gaugeValue = CGFloat(frameIndex) / 360
            let style = RingGaugeStyle(
                color: color(for: key.profile, gaugeValue: gaugeValue),
                displayScale: key.scale,
                profile: key.profile
            )
            guard let image = RingGaugeSpriteRenderer.renderFrame(
                value: gaugeValue,
                style: style
            ) else {
                continue
            }

            context.draw(image, in: frameRect(for: frameIndex, frameSize: frameSize, columns: columns))
        }

        guard let image = context.makeImage() else {
            return fallbackAtlas()
        }

        return RingGaugeAtlas(image: image, columns: columns, rows: rows)
    }
}

private extension RingGaugeAtlasRenderer {
    static func color(for profile: GaugeColorProfile, gaugeValue: CGFloat) -> LayerColorComponents {
        LayerColorComponents.threshold(profile.level(for: gaugeValue))
    }

    static func frameRect(for frameIndex: Int, frameSize: Int, columns: Int) -> CGRect {
        let column = frameIndex % columns
        let row = frameIndex / columns
        return CGRect(
            x: column * frameSize,
            y: row * frameSize,
            width: frameSize,
            height: frameSize
        )
    }

    static func fallbackAtlas() -> RingGaugeAtlas {
        let pixel = NSColor.clear.cgColor
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            let image = pixelPlaceholderImage(color: pixel)
            return RingGaugeAtlas(image: image, columns: 1, rows: 1)
        }

        if let image = context.makeImage() {
            return RingGaugeAtlas(image: image, columns: 1, rows: 1)
        }

        let image = pixelPlaceholderImage(color: pixel)
        return RingGaugeAtlas(image: image, columns: 1, rows: 1)
    }

    static func pixelPlaceholderImage(color: CGColor) -> CGImage {
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            preconditionFailure("Failed to create placeholder image context")
        }
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let image = context.makeImage() else {
            preconditionFailure("Failed to create placeholder image")
        }
        return image
    }
}
