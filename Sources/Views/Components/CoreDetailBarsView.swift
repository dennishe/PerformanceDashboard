import SwiftUI

struct CoreDetailBarsView: View {
    let section: DetailModel.SupplementarySection

    private let columns = [
        GridItem(.flexible(), spacing: DashboardDesign.Spacing.small),
        GridItem(.flexible(), spacing: DashboardDesign.Spacing.small)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DashboardDesign.Spacing.small) {
            Text(verbatim: section.title)
                .font(.system(size: DashboardDesign.FontSize.tileSubtitle, weight: .semibold))
                .foregroundStyle(.secondary)
            ScrollView(.vertical) {
                LazyVGrid(columns: columns, alignment: .leading, spacing: DashboardDesign.Spacing.small) {
                    ForEach(section.items) { item in
                        coreBar(item)
                    }
                }
            }
        }
        .frame(height: 160)
    }

    private func coreBar(_ item: DetailModel.SupplementaryItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 2) {
                Text(verbatim: item.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Text(verbatim: item.value)
                    .monospacedDigit()
            }
            .font(.system(size: DashboardDesign.FontSize.tileSubtitle, weight: .medium))
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(Color.threshold(MetricThresholds.cpu.level(for: item.gaugeValue)))
                        .frame(width: geometry.size.width * min(max(item.gaugeValue, 0), 1))
                }
            }
            .frame(height: 5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.label), \(item.subtitle ?? "Core"), \(item.value)")
        .accessibilityValue(item.value)
    }
}

#Preview {
    CoreDetailBarsView(section: .init(
        title: "Per-core",
        items: (0..<18).map { index in
            .init(
                label: "CPU \(index + 1)",
                subtitle: index < 12 ? "Performance" : "Efficiency",
                value: "42.0%",
                gaugeValue: 0.42
            )
        }
    ))
    .frame(width: 220)
    .padding()
}
