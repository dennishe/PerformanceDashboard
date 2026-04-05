import AppKit

/// Activates the app as a regular GUI foreground application when launched
/// directly as an SPM executable (i.e. via `swift run`), where no app bundle
/// is present to signal this automatically to macOS.
final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        applyAppIcon()
    }

    // Sets the Dock icon from the SPM resource bundle. This is needed when
    // running via `swift run` where no .app bundle exists to supply the icon.
    @MainActor
    private func applyAppIcon() {
        guard
            let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
            let icon = NSImage(contentsOf: url)
        else { return }
        NSApp.applicationIconImage = icon
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
