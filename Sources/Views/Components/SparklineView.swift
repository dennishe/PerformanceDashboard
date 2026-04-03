import SwiftUI

/// Reusable sparkline drawn with `Canvas` for performance.
/// Renders a gradient-filled area chart beneath a smooth line.
struct SparklineView: View {
    let history: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard history.count > 1 else { return }
            let maxValue = max(history.max() ?? 1, 0.001)
            let step = size.width / Double(history.count - 1)
            // Reserve 10% top padding so the line never clips to the edge.
            let yScale = size.height * 0.88

            var points: [CGPoint] = []
            for (index, value) in history.enumerated() {
                points.append(CGPoint(
                    x: Double(index) * step,
                    y: size.height - (value / maxValue) * yScale
                ))
            }

            guard let first = points.first, let last = points.last else { return }

            // Gradient fill below the line.
            var fillPath = Path()
            fillPath.move(to: CGPoint(x: first.x, y: size.height))
            fillPath.addLine(to: first)
            for point in points.dropFirst() { fillPath.addLine(to: point) }
            fillPath.addLine(to: CGPoint(x: last.x, y: size.height))
            fillPath.closeSubpath()
            context.fill(fillPath, with: .linearGradient(
                Gradient(colors: [color.opacity(0.22), color.opacity(0.02)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            ))

            // Line on top of the fill.
            var linePath = Path()
            linePath.move(to: first)
            for point in points.dropFirst() { linePath.addLine(to: point) }
            context.stroke(linePath, with: .color(color),
                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .accessibilityLabel("Sparkline chart")
        .accessibilityValue(history.last.map { String(format: "%.1f%%", $0 * 100) } ?? "No data")
    }
}

#Preview {
    SparklineView(history: (0..<60).map { _ in Double.random(in: 0...1) }, color: .green)
        .frame(width: 200, height: 60)
        .padding()
}
