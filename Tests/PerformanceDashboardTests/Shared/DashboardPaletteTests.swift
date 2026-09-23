import AppKit
import Testing
@testable import PerformanceDashboard

struct DashboardPaletteTests {
    @Test func metricAccents_shareOnePaletteAcrossSurfaces() {
        let cpu = DashboardPalette.accent(title: "CPU", level: .normal, dark: true)
        let battery = DashboardPalette.accent(title: "Battery", level: .normal, dark: true)
        let gpu = DashboardPalette.accent(title: "GPU", level: .normal, dark: true)
        let temperature = DashboardPalette.accent(title: "Temperature", level: .normal, dark: true)

        #expect(cpu == battery)
        #expect(cpu != gpu)
        #expect(cpu != temperature)
        #expect(DashboardPalette.accent(title: "GPU", level: .normal, dark: false) != gpu)
    }

    @Test func batteryWarning_overridesNormalAccent() {
        let warning = DashboardPalette.accent(title: "Battery", level: .warning, dark: true)
        let critical = DashboardPalette.accent(title: "Battery", level: .critical, dark: false)

        #expect(warning == .systemOrange)
        #expect(critical == .systemRed)
    }

    @Test @MainActor func preparedTileLabels_resolveForCurrentAppearance() throws {
        let light = try #require(NSAppearance(named: .aqua))
        let dark = try #require(NSAppearance(named: .darkAqua))
        let prepared = PreparedTileTextStyle(style: .tileCaption())

        let lightText = prepared.attributedString("CPU", appearance: light)
        let darkText = prepared.attributedString("CPU", appearance: dark)
        let lightColor = try #require(lightText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
        let darkColor = try #require(darkText.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)

        #expect(lightColor.redComponent < darkColor.redComponent)
    }
}
