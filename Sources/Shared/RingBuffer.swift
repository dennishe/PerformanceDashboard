import Foundation

func ringBufferAppending<Element>(_ buffer: [Element], value: Element, maxCount: Int) -> [Element] {
    var updated = buffer
    updated.append(value)
    if updated.count > maxCount {
        updated.removeFirst(updated.count - maxCount)
    }
    return updated
}
