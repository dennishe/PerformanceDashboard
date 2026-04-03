import AppKit

/// Activates the app as a regular GUI foreground application when launched
/// directly as an SPM executable (i.e. via `swift run`), where no app bundle
/// is present to signal this automatically to macOS.
final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
