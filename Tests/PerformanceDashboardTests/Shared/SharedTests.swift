import Testing
import SwiftUI
@testable import PerformanceDashboard

struct ColorThresholdTests {
    @Test func color_normal_isGreen() {
        #expect(Color.threshold(.normal) == .green)
    }

    @Test func color_warning_isOrange() {
        #expect(Color.threshold(.warning) == .orange)
    }

    @Test func color_critical_isRed() {
        #expect(Color.threshold(.critical) == .red)
    }
}

struct ConstantsTests {
    @Test func pollingInterval_isOneSecond() {
        #expect(Constants.pollingInterval == .seconds(1))
    }

    @Test func historySamples_isSixty() {
        #expect(Constants.historySamples == 60)
    }
}

struct DashboardGridMetricsTests {
    @Test func rowCount_countsExactFullRows() {
        #expect(DashboardGridMetrics.rowCount(spans: [1, 1, 1, 1], columns: 2) == 2)
    }

    @Test func rowCount_countsWrappedRows() {
        #expect(DashboardGridMetrics.rowCount(spans: [2, 1, 2, 1, 1], columns: 3) == 3)
    }
}

// MARK: - PollingCadenceTests

struct PollingCadenceTests {
    @Test func tolerance_isTwentyFiveMilliseconds() {
        #expect(PollingCadence.tolerance == .milliseconds(25))
    }

    @Test func initialDeadline_isApproximatelyOnePollingIntervalInFuture() {
        let before = PollingCadence.clock.now
        let deadline = PollingCadence.initialDeadline()
        let expected = before.advanced(by: Constants.pollingInterval)
        #expect(deadline >= expected)
        #expect(deadline <= expected.advanced(by: .milliseconds(100)))
    }

    @Test func nextDeadline_advancesExactlyByPollingInterval() {
        let base = PollingCadence.clock.now
        let next = PollingCadence.nextDeadline(after: base)
        let expected = base.advanced(by: Constants.pollingInterval)
        #expect(next == expected)
    }

    @Test func nextDeadline_chained_advancesByTwoIntervals() {
        let base = PollingCadence.clock.now
        let first = PollingCadence.nextDeadline(after: base)
        let second = PollingCadence.nextDeadline(after: first)
        let expected = base
            .advanced(by: Constants.pollingInterval)
            .advanced(by: Constants.pollingInterval)
        #expect(second == expected)
    }

    @Test func nextDeadline_isStrictlyAfterInput() {
        let base = PollingCadence.clock.now
        let next = PollingCadence.nextDeadline(after: base)
        #expect(next > base)
    }
}

// MARK: - DashboardSettingsTests

struct DashboardSettingsTests {
    @Test func toggle_changesVisibility() {
        let settings = DashboardSettings()
        let before = settings.isVisible(.cpu)
        settings.toggle(.cpu)
        #expect(settings.isVisible(.cpu) != before)
    }

    @Test func toggle_togglesBackToOriginal() {
        let settings = DashboardSettings()
        let before = settings.isVisible(.gpu)
        settings.toggle(.gpu)
        settings.toggle(.gpu)
        #expect(settings.isVisible(.gpu) == before)
    }

    @Test func hiddenTileIDs_consistency_withIsVisible() {
        let settings = DashboardSettings()
        for tile in TileID.allCases {
            let hidden = settings.hiddenTileIDs.contains(tile.rawValue)
            #expect(settings.isVisible(tile) == !hidden)
        }
    }

    @Test func toggle_addsToHiddenTileIDs() {
        let settings = DashboardSettings()
        if settings.isVisible(.disk) {
            settings.toggle(.disk)
            #expect(settings.hiddenTileIDs.contains("disk"))
        } else {
            settings.toggle(.disk)
            #expect(!settings.hiddenTileIDs.contains("disk"))
        }
    }

    @Test func tileID_rawValues_matchExpected() {
        #expect(TileID.cpu.rawValue == "cpu")
        #expect(TileID.gpu.rawValue == "gpu")
        #expect(TileID.memory.rawValue == "memory")
        #expect(TileID.network.rawValue == "network")
        #expect(TileID.disk.rawValue == "disk")
    }

    @Test func densityPreset_isValidCase() {
        let settings = DashboardSettings()
        #expect(DensityPreset.allCases.contains(settings.densityPreset))
    }

    @Test func densityPreset_comfortable_hasTileWidth() {
        #expect(DensityPreset.comfortable.minTileWidth > 0)
    }

    @Test func densityPreset_compact_hasNarrowerTileWidth() {
        #expect(DensityPreset.compact.minTileWidth < DensityPreset.comfortable.minTileWidth)
    }

    @Test func tileID_displayName_isNonEmpty() {
        for tile in TileID.allCases {
            #expect(!tile.displayName.isEmpty)
        }
    }

    @Test func tileID_available_isSubsetOfAllCases() {
        let available = TileID.available
        let allCases = TileID.allCases
        #expect(available.count <= allCases.count)
        for tile in available {
            #expect(allCases.contains(tile))
        }
    }
}
