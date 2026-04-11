import SwiftUI

struct BatteryAccessorySectionHeader: View {
    let title: String
    let connectedCount: Int
    let fontSize: CGFloat
    let countFontSize: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DashboardDesign.Spacing.small) {
            Text(title)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if connectedCount > 0 {
                Text(verbatim: "\(connectedCount) connected")
                    .font(.system(size: countFontSize, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct BatteryAccessoryEmptyStateView: View {
    let message: String
    let isProminent: Bool

    var body: some View {
        Text(verbatim: message)
            .font(
                .system(
                    size: isProminent ? DashboardDesign.FontSize.tileBody : 12,
                    weight: .medium
                )
            )
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BatteryPrimaryMeter: View {
    let fraction: Double
    let thresholdLevel: ThresholdLevel

    var body: some View {
        GeometryReader { proxy in
            let trackWidth = max(0, proxy.size.width - 6)
            let fillWidth = max(6, trackWidth * fraction)

            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.threshold(thresholdLevel))
                        .frame(width: fillWidth)
                        .padding(2)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
                .overlay(alignment: .trailing) {
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.22))
                        .frame(width: 4, height: 10)
                        .offset(x: 7)
                }
        }
        .frame(width: 40, height: 16)
        .padding(.trailing, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This Mac battery gauge")
        .accessibilityValue("\(Int((fraction * 100).rounded()))%")
    }
}

struct BatteryAccessoryDockRowView: View {
    let row: BatteryTileGaugeRow
    let isProminent: Bool

    private var kind: BatteryAccessoryKind {
        BatteryAccessoryKind.infer(from: row.name)
    }

    private var componentBadge: String? {
        BatteryAccessoryKind.componentBadge(for: row.name)
    }

    var body: some View {
        HStack(spacing: 8) {
            BatteryAccessoryGlyph(
                symbolName: kind.symbolName,
                componentBadge: componentBadge,
                thresholdLevel: row.thresholdLevel,
                isProminent: isProminent
            )

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.secondary.opacity(0.11))

                    Capsule(style: .continuous)
                        .fill(Color.threshold(row.thresholdLevel))
                        .frame(width: proxy.size.width * row.fraction)
                }
            }
            .frame(height: isProminent ? 5 : 4)

            Text(verbatim: row.valueText)
                .font(
                    .system(
                        size: isProminent ? 13 : 12,
                        weight: .semibold,
                        design: .rounded
                    )
                    .monospacedDigit()
                )
                .foregroundStyle(Color.threshold(row.thresholdLevel))
                .contentTransition(.numericText())
        }
        .help(row.name)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.name)
        .accessibilityValue(row.valueText)
    }
}

private struct BatteryAccessoryGlyph: View {
    let symbolName: String
    let componentBadge: String?
    let thresholdLevel: ThresholdLevel
    let isProminent: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: isProminent ? 9 : 8, style: .continuous)
            .fill(Color.primary.opacity(isProminent ? 0.07 : 0.055))
            .overlay {
                RoundedRectangle(cornerRadius: isProminent ? 9 : 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            }
            .overlay {
                Image(systemName: symbolName)
                    .font(.system(size: isProminent ? 11 : 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .overlay(alignment: .bottomTrailing) {
                if let componentBadge {
                    Text(verbatim: componentBadge)
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Capsule(style: .continuous).fill(Color.tileSurface))
                        .offset(x: 4, y: 4)
                }
            }
            .frame(width: isProminent ? 24 : 22, height: isProminent ? 24 : 22)
    }
}
