import SwiftUI

/// Reusable sparkline drawn with `Canvas` for performance.
struct SparklineView: View {
    let history: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard history.count > 1 else { return }
            let maxValue = history.max() ?? 1
            let step = size.width / Double(history.count - 1)

            var path = Path()
            for (index, value) in history.enumerated() {
                let x = Double(index) * step
                let y = size.height - (value / max(maxValue, 0.001)) * size.height
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            context.stroke(path, with: .color(color), lineWidth: 1.5)
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
