import Foundation

enum BatteryAccessoryKind: Equatable {
    case keyboard
    case pointingDevice
    case headphones
    case phone
    case watch
    case stylus
    case unknown

    var symbolName: String {
        switch self {
        case .keyboard: "keyboard"
        case .pointingDevice: "computermouse"
        case .headphones: "headphones"
        case .phone: "iphone"
        case .watch: "applewatch"
        case .stylus: "pencil"
        case .unknown: "dot.radiowaves.left.and.right"
        }
    }

    static func infer(from deviceName: String) -> BatteryAccessoryKind {
        let normalized = deviceName.lowercased()

        if normalized.contains("keyboard") {
            return .keyboard
        }

        if normalized.contains("mouse") || normalized.contains("trackpad") {
            return .pointingDevice
        }

        if normalized.contains("airpods")
            || normalized.contains("headphone")
            || normalized.contains("headset")
            || normalized.contains("earbud")
            || normalized.contains("beats")
            || normalized.contains("buds") {
            return .headphones
        }

        if normalized.contains("iphone") {
            return .phone
        }

        if normalized.contains("watch") {
            return .watch
        }

        if normalized.contains("pencil") || normalized.contains("stylus") {
            return .stylus
        }

        return .unknown
    }

    static func componentBadge(for deviceName: String) -> String? {
        let normalized = deviceName.lowercased()

        if normalized.hasSuffix("(left)") {
            return "L"
        }

        if normalized.hasSuffix("(right)") {
            return "R"
        }

        if normalized.hasSuffix("(case)") {
            return "C"
        }

        return nil
    }
}
