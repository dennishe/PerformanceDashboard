import SwiftUI

/// A ring / arc gauge showing a single normalised value in [0, 1].
struct RingGaugeView: View {
    let value: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(value, 1))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: value)
        }
        .accessibilityLabel("Ring gauge")
        .accessibilityValue(String(format: "%.1f%%", value * 100))
    }
}

#Preview {
    RingGaugeView(value: 0.72, color: .orange)
        .frame(width: 80, height: 80)
        .padding()
}
