import Foundation

extension Double {
    func percentFormatted() -> String {
        String(format: "%.1f%%", self * 100)
    }

    func celsiusFormatted() -> String {
        String(format: "%.1f°C", self)
    }

    func wattsFormatted(precision: Int = 1) -> String {
        String(format: precision == 2 ? "%.2f W" : "%.1f W", self)
    }

    func milliwattsFormatted() -> String {
        String(format: "%.0f mW", self)
    }

    func rpmFormatted() -> String {
        String(format: "%.0f RPM", self)
    }
}
