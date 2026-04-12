import Foundation
import Testing
@testable import PerformanceDashboard

struct DashboardSettingsPersistenceTests {
    private func makeIsolatedDefaults(
        name: String = #function
    ) -> (defaults: UserDefaults, suiteName: String) {
        let suiteName = "DashboardSettingsPersistenceTests.\(name)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Unable to create UserDefaults suite for \(suiteName)")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    @Test func init_fallsBackToComfortableDensity_whenStoredValueIsInvalid() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }
        context.defaults.set("invalid", forKey: "pd.densityPreset")

        let settings = DashboardSettings(userDefaults: context.defaults)

        #expect(settings.densityPreset == .comfortable)
    }

    @Test func densityPreset_persistsAcrossInstances() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let settings = DashboardSettings(userDefaults: context.defaults)
        settings.densityPreset = .compact

        let reloaded = DashboardSettings(userDefaults: context.defaults)

        #expect(reloaded.densityPreset == .compact)
    }

    @Test func hiddenTiles_persistAcrossInstances() {
        let context = makeIsolatedDefaults()
        defer { context.defaults.removePersistentDomain(forName: context.suiteName) }

        let settings = DashboardSettings(userDefaults: context.defaults)
        settings.toggle(.gpu)
        settings.toggle(.disk)

        let reloaded = DashboardSettings(userDefaults: context.defaults)

        #expect(reloaded.isVisible(.gpu) == false)
        #expect(reloaded.isVisible(.disk) == false)
        #expect(reloaded.hiddenTileIDs == ["disk", "gpu"])
    }
}
