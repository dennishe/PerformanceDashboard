import Foundation

enum AppFormatters {
    static func byteCountString(_ byteCount: Int64, style: ByteCountFormatter.CountStyle) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = style
        return formatter.string(fromByteCount: byteCount)
    }
}
