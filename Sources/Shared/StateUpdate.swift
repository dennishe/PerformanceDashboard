import Foundation

func assignIfChanged<Value: Equatable>(_ value: inout Value, to newValue: Value) {
    if value != newValue {
        value = newValue
    }
}
