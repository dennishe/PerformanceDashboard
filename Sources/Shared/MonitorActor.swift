import Darwin

/// Global actor that runs all system API polling off the main thread.
@globalActor
public actor MonitorActor: GlobalActor {
    public static let shared = MonitorActor()
}
