@testable import PerformanceDashboard

final class MockSMCReader: SMCReading {
    private let readings: [String: (dataType: UInt32, bytes: [UInt8])]

    init(readings: [String: (dataType: UInt32, bytes: [UInt8])]) {
        self.readings = readings
    }

    func readBytes(key: String) -> (dataType: UInt32, bytes: [UInt8])? {
        readings[key]
    }
}
