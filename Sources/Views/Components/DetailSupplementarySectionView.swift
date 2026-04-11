import SwiftUI

struct DetailSupplementarySectionView: View {
    let section: DetailModel.SupplementarySection

    private let columns = [
        GridItem(.flexible(), spacing: DashboardDesign.Spacing.regular),
        GridItem(.flexible(), spacing: DashboardDesign.Spacing.regular)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DashboardDesign.Spacing.compact) {
            Divider().opacity(0.5)
            Text(verbatim: section.title)
                .font(.system(size: DashboardDesign.FontSize.tileBody, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, DashboardDesign.Spacing.large)

            LazyVGrid(columns: columns, spacing: DashboardDesign.Spacing.regular) {
                ForEach(section.items) { item in
                    card(for: item)
                }
            }
            .padding(.horizontal, DashboardDesign.Spacing.large)
            .padding(.bottom, DashboardDesign.Spacing.regular)
        }
    }

    private func card(for item: DetailModel.SupplementaryItem) -> some View {
        VStack(alignment: .leading, spacing: DashboardDesign.Spacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: DashboardDesign.Spacing.small) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: item.label)
                        .font(.system(size: DashboardDesign.FontSize.tileBody, weight: .semibold))
                    if let subtitle = item.subtitle {
                        Text(verbatim: subtitle)
                            .font(.system(size: DashboardDesign.FontSize.tileSubtitle, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: DashboardDesign.Spacing.small)
                Text(verbatim: item.value)
                    .font(
                        .system(
                            size: DashboardDesign.FontSize.tileBody,
                            weight: .semibold,
                            design: .rounded
                        ).monospacedDigit()
                    )
                    .foregroundStyle(.primary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary.opacity(0.7))
                    Capsule()
                        .fill(Color.threshold(thresholdLevel(for: item.gaugeValue)))
                        .frame(width: proxy.size.width * min(max(item.gaugeValue, 0), 1))
                }
            }
            .frame(height: 6)
        }
        .padding(DashboardDesign.Spacing.regular)
        .background(Color.primary.opacity(DashboardDesign.Opacity.tileChrome), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: item))
    }

    private func thresholdLevel(for value: Double) -> ThresholdLevel {
        MetricThresholds.cpu.level(for: value)
    }

    private func accessibilityLabel(for item: DetailModel.SupplementaryItem) -> String {
        if let subtitle = item.subtitle {
            return item.label + ", " + subtitle + ", " + item.value
        }
        return item.label + ": " + item.value
    }
}
