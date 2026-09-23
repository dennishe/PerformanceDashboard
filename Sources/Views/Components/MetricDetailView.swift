import SwiftUI

/// Overlay card that shows a richer view of a single metric: time-series chart with
/// selectable range and per-metric secondary stats. Presented in-page (not a sheet).
struct MetricDetailView: View {
    let model: DetailModel
    let availableHeight: CGFloat?
    let onDismiss: () -> Void
    @State private var selectedRange: TimeRange = .oneMinute

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow(model: model)
            chartSection(model: model)
            if showsSupplementarySections && model.supplementaryPlacement == .belowChart {
                supplementarySections(model.supplementarySections)
            }
            if !model.stats.isEmpty {
                statsSection(stats: model.stats)
            }
        }
        .background(Color.tileSurface, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.tileBorder))
        .shadow(color: .black.opacity(DashboardDesign.Opacity.modalScrim), radius: 40, y: 12)
    }

    private var showsSupplementarySections: Bool {
        guard !model.supplementarySections.isEmpty else { return false }
        if model.supplementaryPlacement == .besideChart { return true }
        guard let availableHeight else { return true }
        return availableHeight >= estimatedRequiredHeight
    }

    private var estimatedRequiredHeight: CGFloat {
        let statHeight = CGFloat(model.stats.count) * 40
        let supplementaryItemCount = model.supplementarySections.reduce(0) { $0 + $1.items.count }
        let supplementaryRows = CGFloat((supplementaryItemCount + 1) / 2)
        let supplementaryHeight = supplementaryRows > 0 ? 72 + supplementaryRows * 58 : 0
        return 270 + statHeight + supplementaryHeight
    }

    // MARK: - Header

    private func headerRow(model: DetailModel) -> some View {
        HStack(spacing: 12) {
            Image(systemName: model.systemImage)
                .font(.system(size: DashboardDesign.FontSize.tileControl, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(verbatim: model.title)
                .font(.system(size: DashboardDesign.FontSize.tileHeader, weight: .semibold))
            Text(verbatim: model.primaryValue)
                .font(
                    .system(size: DashboardDesign.FontSize.tileHeader, weight: .semibold, design: .rounded)
                        .monospacedDigit()
                )
                .foregroundStyle(DashboardPalette.color(title: model.title, level: model.thresholdLevel))
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
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel("Time range")
            Button { onDismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: DashboardDesign.FontSize.tileSubtitle, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 24, height: 24)
                    .background(.quaternary, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, DashboardDesign.Spacing.large)
        .padding(.vertical, DashboardDesign.Spacing.compact)
        .overlay(alignment: .bottom) { Divider().opacity(0.4) }
    }

    // MARK: - Chart

    private func chartSection(model: DetailModel) -> some View {
        let sliced = model.history.suffix(selectedRange.sampleCount)
        let layerColor = LayerColorComponents(nsColor: DashboardPalette.accent(
            title: model.title, level: model.thresholdLevel, appearance: NSApp.effectiveAppearance
        ))
        return HStack(spacing: DashboardDesign.Spacing.regular) {
            SparklineView(
                history: Array(sliced),
                color: layerColor,
                accessibilityLabel: model.title + " history",
                accessibilityValue: model.primaryValue
            )
            .frame(maxWidth: .infinity)
            if showsSupplementarySections && model.supplementaryPlacement == .besideChart,
               let section = model.supplementarySections.first {
                Divider()
                CoreDetailBarsView(section: section)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 160)
        .padding(.horizontal, DashboardDesign.Spacing.large)
        .padding(.top, DashboardDesign.Spacing.medium)
        .padding(.bottom, DashboardDesign.Spacing.regular)
    }

    private func supplementarySections(_ sections: [DetailModel.SupplementarySection]) -> some View {
        VStack(spacing: 0) {
            ForEach(sections) { section in
                DetailSupplementarySectionView(section: section, metricTitle: model.title)
            }
        }
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
                .padding(.horizontal, DashboardDesign.Spacing.large)
                .padding(.vertical, 9)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(stat.label): \(stat.value)")
                if stat.id != stats.last?.id {
                    Divider()
                        .opacity(0.3)
                        .padding(.leading, DashboardDesign.Spacing.large)
                }
            }
        }
        .font(.system(size: DashboardDesign.FontSize.tileBody))
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
    return MetricDetailView(
        model: DetailModel(
            title: "CPU",
            systemImage: "cpu",
            primaryValue: "42.3%",
            thresholdLevel: .normal,
            history: (0..<60).map { _ in Double.random(in: 0...0.5) },
            supplementarySections: [
                .init(title: "Per-core", items: [
                    .init(label: "CPU 1", subtitle: "Performance", value: "72.0%", gaugeValue: 0.72),
                    .init(label: "CPU 2", subtitle: "Efficiency", value: "18.0%", gaugeValue: 0.18)
                ])
            ],
            supplementaryPlacement: .besideChart,
            stats: [
                .init(label: "Usage", value: "42.3%")
            ]
        ),
        availableHeight: 720,
        onDismiss: {}
    )
        .frame(width: 480)
        .padding()
}
