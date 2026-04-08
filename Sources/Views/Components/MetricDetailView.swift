import SwiftUI

/// Overlay card that shows a richer view of a single metric: time-series chart with
/// selectable range and per-metric secondary stats. Presented in-page (not a sheet).
struct MetricDetailView: View {
    let viewModel: any DetailPresenting
    let onDismiss: () -> Void
    @State private var selectedRange: TimeRange = .oneMinute

    var body: some View {
        let model = viewModel.detailModel
        VStack(alignment: .leading, spacing: 0) {
            headerRow(model: model)
            chartSection(model: model)
            if !model.stats.isEmpty {
                statsSection(stats: model.stats)
            }
        }
        .background(Color.tileSurface, in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.45), radius: 40, y: 12)
        .overlay(alignment: .topTrailing) {
            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .padding(5)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .padding(.top, 10)
            .padding(.trailing, 12)
        }
    }

    // MARK: - Header (single compact bar, close button lives in body overlay)

    private func headerRow(model: DetailModel) -> some View {
        HStack(spacing: 6) {
            Image(systemName: model.systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: model.title)
                .font(.system(size: 13, weight: .semibold))
            Text(verbatim: model.primaryValue)
                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.threshold(model.thresholdLevel))
                .contentTransition(.numericText())
                .padding(.leading, 2)
            Spacer(minLength: 8)
            Picker(selection: $selectedRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.label).tag(range)
                }
            } label: { EmptyView() }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 148)
            .accessibilityLabel("Time range")
        }
        // Right padding leaves space for the floating close button overlay.
        .padding(.leading, 16)
        .padding(.trailing, 52)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Divider().opacity(0.4) }
    }

    // MARK: - Chart

    private func chartSection(model: DetailModel) -> some View {
        let sliced = model.history.suffix(selectedRange.sampleCount)
        let layerColor = LayerColorComponents.threshold(model.thresholdLevel)
        return SparklineView(
            history: Array(sliced),
            color: layerColor,
            accessibilityLabel: model.title + " history",
            accessibilityValue: model.primaryValue
        )
        .frame(height: 160)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    // MARK: - Stats

    private func statsSection(stats: [DetailModel.Stat]) -> some View {
        VStack(spacing: 0) {
            Divider().opacity(0.5)
            ForEach(stats) { stat in
                HStack {
                    Text(verbatim: stat.label)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(verbatim: stat.value)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(stat.label): \(stat.value)")
                if stat.id != stats.last?.id {
                    Divider()
                        .opacity(0.3)
                        .padding(.leading, 16)
                }
            }
        }
        .font(.system(size: 13))
    }
}

// MARK: - Time range

private enum TimeRange: CaseIterable {
    case oneMinute, fiveMinutes, fifteenMinutes

    var label: String {
        switch self {
        case .oneMinute: "1 min"
        case .fiveMinutes: "5 min"
        case .fifteenMinutes: "15 min"
        }
    }

    var sampleCount: Int {
        switch self {
        case .oneMinute: Constants.historySamples
        case .fiveMinutes: 300
        case .fifteenMinutes: Constants.extendedHistorySamples
        }
    }
}

#Preview {
    final class MockDetail: DetailPresenting {
        var detailModel: DetailModel {
            DetailModel(
                title: "CPU",
                systemImage: "cpu",
                primaryValue: "42.3%",
                thresholdLevel: .normal,
                history: (0..<60).map { _ in Double.random(in: 0...0.5) },
                stats: [
                    .init(label: "Usage", value: "42.3%")
                ]
            )
        }
    }
    return MetricDetailView(viewModel: MockDetail(), onDismiss: {})
        .frame(width: 480)
        .padding()
}
