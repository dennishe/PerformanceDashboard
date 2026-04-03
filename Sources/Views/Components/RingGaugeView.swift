import SwiftUI

/// A ring / arc gauge showing a single normalised value in [0, 1].
/// `AnimatedRingGauge` conforms to `Animatable`; SwiftUI interpolates `value`
/// frame-by-frame when it changes, stepping through the 360 cached degree images.
///
/// All layout and accessibility modifiers live on this wrapper (re-evaluated only
/// when `value` actually changes) so `AnimatedRingGauge.body` is bare — just an
/// image lookup — and can run 60 fps without string formatting or layout overhead.
/// Color resolution is performed once here (1 Hz) rather than inside the Animatable
/// primitive (60 fps) to avoid per-frame `EnvironmentValues` allocations.
struct RingGaugeView: View {
    let value: Double
    let color: Color

    @Environment(\.self) private var environment

    var body: some View {
        let resolved = color.resolve(in: environment)
        AnimatedRingGauge(value: value, resolved: resolved)
            .animation(.easeInOut(duration: 0.3), value: value)
            // Fixed frame declared here so SwiftUI knows the gauge is constant-size
            // without measuring AnimatedRingGauge on every animation tick.
            .frame(width: RingGaugeCache.displayDiameter, height: RingGaugeCache.displayDiameter)
            .contentTransition(.identity)
            .accessibilityLabel("Ring gauge")
            .accessibilityValue(String(format: "%.1f%%", value * 100))
    }
}

// MARK: - Animatable primitive

private struct AnimatedRingGauge: View, @preconcurrency Animatable {
    // var required — Animatable's setter mutates this each frame
    var value: Double
    let resolved: Color.Resolved

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    // body is intentionally bare: only a CGImage cache lookup + Image init per frame.
    // No Color.resolve, no EnvironmentValues, no String formatting.
    var body: some View {
        if let image = RingGaugeCache.shared.image(for: value, resolved: resolved) {
            Image(decorative: image, scale: 2)
                .resizable()
        }
    }
}

#Preview {
    RingGaugeView(value: 0.72, color: .orange)
        .padding()
}
