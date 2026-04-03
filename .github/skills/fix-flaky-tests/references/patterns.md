# Root-Cause Patterns & Fix Recipes

Each section covers one flakiness category: what it looks like, why it breaks, and how to fix it.

---

## A — Sleep-then-assert

### Signal
```swift
try? await Task.sleep(for: .milliseconds(50))
#expect(mock.receivedMessages.count == 1)
```

### Why it breaks
The fixed delay is long enough locally but not on a loaded CI runner. Any async side-effect that hasn't completed within the window causes a spurious failure.

### Fix — Confirmation continuation
Have the mock signal completion instead of sleeping.

```swift
// Add to the mock actor:
actor MockSink {
    private var continuation: CheckedContinuation<Void, Never>?

    func waitForNext() async {
        await withCheckedContinuation { self.continuation = $0 }
    }

    func received(_ value: SomeType) {
        receivedValues.append(value)
        continuation?.resume()
        continuation = nil
    }
}

// In the test — no sleep needed:
async let receipt: Void = mock.waitForNext()
triggerOperation()
await receipt
#expect(mock.receivedValues.count == 1)
```

### Fix — Polled wait (last resort)
Use only when you cannot modify the mock:
```swift
func waitUntil(
    _ condition: @escaping () async -> Bool,
    timeout: Duration = .seconds(2)
) async -> Bool {
    let deadline = ContinuousClock().now.advanced(by: timeout)
    while ContinuousClock().now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return false
}

let stable = await waitUntil { await mock.receivedValues.count == 1 }
#expect(stable)
```

---

## B — Shared Mutable State

### Signal
A `var` or actor property at suite scope that multiple `@Test` functions read and write without ordering guarantees.

### Why it breaks
Swift Testing runs `@Test` functions concurrently by default. Concurrent writes to unprotected state produce data races; concurrent reads after writes produce torn state.

### Fix — Per-test isolated context (preferred)
```swift
@Test func example() async {
    // Build a fresh context for every test run
    let context = await TestContext.make()
    // use context — no shared state
}
```

### Fix — `.serialized` tag (acceptable for external state)
```swift
@Suite(.serialized)
struct MyTests {
    // tests run sequentially; safe to share external resources
}
```

---

## C — Leaked External State

### Signal
A test creates a temp file, inserts into a global registry, or leaves shared state (e.g. a running monitor actor) — and the next test run finds it.

### Why it breaks
Shared file-system paths or in-memory registries accumulate state across test iterations, causing assertion failures on re-runs or in unexpected ordering.

### Fix — Unique path per test + `defer` cleanup
```swift
@Test func fileRoundtrip() async throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }

    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    // ... rest of test
}
```

### Fix — Registry reset
If the subject under test owns a global registry, add a `reset()` method and call it at teardown:
```swift
defer { await MyGlobalRegistry.shared.reset() }
```

---

## D — Detached Teardown Race

### Signal
```swift
defer { Task { await controller.stop() } }
```

### Why it breaks
The detached `Task` is fired-and-forgotten. Swift Testing moves on to the next test before `stop()` completes, so the next test's setup races with the previous test's teardown.

### Fix — Await teardown explicitly
```swift
// Remove the defer block, call stop() at the end of the test body:
// ... test body ...
await controller.stop()
```

If the function can throw, cover both paths:
```swift
do {
    // ... test body ...
} catch {
    await controller.stop()
    throw error
}
await controller.stop()
```

---

## E — NSLock / NSCondition Timeout Too Short

### Signal
```swift
lockCondition.wait(until: Date().addingTimeInterval(0.01))
```

### Why it breaks
10 ms is often not enough on CI, especially when the machine is under load from parallel test jobs.

### Fix — Raise timeout to ≥ 2 seconds
```swift
lockCondition.wait(until: Date().addingTimeInterval(2.0))
```

### Better fix — Replace with async/await continuation
If the lock is wrapping an asynchronous readiness signal, replace it entirely:
```swift
// Instead of NSCondition:
private var readyContinuations: [CheckedContinuation<Void, Never>] = []

func waitUntilReady() async {
    await withCheckedContinuation { readyContinuations.append($0) }
}

func signalReady() {
    readyContinuations.forEach { $0.resume() }
    readyContinuations.removeAll()
}
```

---

## F — Nanosecond Serial Timing

### Signal
```swift
serial.enqueueRead([0x06])                         // ACK
try? await Task.sleep(nanoseconds: 10_000_000)     // 10ms gap
serial.enqueueRead([0x01, 0x09, ...])              // callback frame
```

### Why it breaks
The 10 ms gap mimics real hardware but is tight enough to fail when the test runner is loaded. The read queuing is also order-sensitive.

### Fix — Demand-driven mock serial port
Instead of pre-queuing reads with sleep gaps, have `MockSerialPort` emit frames on demand when the sender issues a command:

```swift
actor MockSerialPort: SerialPortProtocol {
    // Map command byte → response frames
    var autoResponses: [UInt8: [[UInt8]]] = [:]

    func write(_ data: Data) async throws {
        let commandByte = data[2]          // adjust offset for your frame format
        if let responses = autoResponses[commandByte] {
            for frame in responses {
                pendingReads.append(contentsOf: frame)
            }
            readCondition.signal()
        }
    }
}

// In the test — no sleep between enqueues:
serial.autoResponses[0x13] = [
    [0x06],                 // ACK
    [0x01, 0x09, ...]       // callback
]
```

This synchronizes the response exactly to the moment the command arrives, removing all timing dependencies.
