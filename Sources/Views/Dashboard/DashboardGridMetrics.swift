import Foundation

enum DashboardGridMetrics {
    static func rowCount(spans: [Int], columns: Int) -> Int {
        guard columns > 0, !spans.isEmpty else { return 0 }

        var rows = 0
        var col = 0

        for span in spans {
            if col == 0 {
                rows += 1
            }
            if col + span > columns {
                rows += 1
                col = 0
            }
            col += span
            if col == columns {
                col = 0
            }
        }

        return rows
    }
}
