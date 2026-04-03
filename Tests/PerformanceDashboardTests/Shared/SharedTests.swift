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
