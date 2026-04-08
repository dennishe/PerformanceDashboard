import SwiftUI

/// Popover that lets users toggle tile visibility and choose a layout density preset.
struct SettingsPanelView: View {
    @Bindable var settings: DashboardSettings

    private let tileColumns = [GridItem(.flexible(), alignment: .leading),
                               GridItem(.flexible(), alignment: .leading)]

    var body: some View {
        VStack(alignment: .leading, spacing: DashboardDesign.Spacing.medium) {
            densitySection
            Divider()
            visibilitySection
        }
        .padding(DashboardDesign.Spacing.medium)
        .frame(width: 270)
    }

    // MARK: - Density

    private var densitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Layout Density")
            Picker("", selection: $settings.densityPreset) {
                ForEach(DensityPreset.allCases, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - Tile visibility

    private var visibilitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader("Visible Tiles")
            LazyVGrid(columns: tileColumns, spacing: 2) {
                ForEach(TileID.available, id: \.self) { tile in
                    Toggle(isOn: Binding(
                        get: { settings.isVisible(tile) },
                        set: { _ in settings.toggle(tile) }
                    )) {
                        Text(tile.displayName)
                            .lineLimit(1)
                    }
                    .toggleStyle(.checkbox)
                    .font(.system(size: DashboardDesign.FontSize.tileControl))
                }
            }
        }
    }

    private func sectionHeader(_ label: String) -> some View {
        Text(label)
            .font(.system(size: DashboardDesign.FontSize.tileCaption, weight: .semibold))
            .foregroundStyle(.secondary)
            .tracking(0.6)
            .textCase(.uppercase)
    }
}

#Preview {
    SettingsPanelView(settings: DashboardSettings())
}
