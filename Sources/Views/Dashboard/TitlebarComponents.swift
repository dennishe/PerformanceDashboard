import SwiftUI
import AppKit

// MARK: - NSWindow configurator

/// Injects a SwiftUI title view directly into the AppKit titlebar container
/// (the superview of the traffic-light buttons) so it is always rendered as
/// part of the titlebar layer — never behind it.
///
/// Also places a settings button on the trailing side of the titlebar that
/// opens `SettingsPanelView` in an `NSPopover`.
@MainActor
struct TitlebarConfigurator: NSViewRepresentable {
    let onSettingsTapped: @MainActor () -> Void
    @Binding var isSettingsVisible: Bool
    let settings: DashboardSettings

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { @MainActor in
            guard let window = view.window else { return }
            context.coordinator.attach(to: window, settings: settings)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Keep the popover's hosted settings in sync when state changes.
        context.coordinator.updateSettings(settings)
    }

    @MainActor
    final class Coordinator {
        private var titleView: NSView?
        private var settingsButtonView: NSView?
        private var popover: NSPopover?
        private var settingsHostingVC: NSHostingController<SettingsPanelView>?

        func attach(to window: NSWindow, settings: DashboardSettings) {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.backgroundColor = .windowBackgroundColor

            guard let closeButton = window.standardWindowButton(.closeButton),
                  let titlebarContainer = closeButton.superview else { return }

            // Leading: "Performance •" status label
            titleView?.removeFromSuperview()
            let statusView = TitlebarStatusView()
            titlebarContainer.addSubview(statusView)
            NSLayoutConstraint.activate([
                statusView.centerYAnchor.constraint(equalTo: titlebarContainer.centerYAnchor),
                statusView.leadingAnchor.constraint(equalTo: titlebarContainer.leadingAnchor,
                                                    constant: 76)
            ])
            titleView = statusView

            // Trailing: settings button
            settingsButtonView?.removeFromSuperview()
            let settingsView = makeSettingsButton(titlebarContainer: titlebarContainer, settings: settings)
            titlebarContainer.addSubview(settingsView)
            NSLayoutConstraint.activate([
                settingsView.centerYAnchor.constraint(equalTo: titlebarContainer.centerYAnchor),
                settingsView.trailingAnchor.constraint(equalTo: titlebarContainer.trailingAnchor,
                                                       constant: -12)
            ])
            settingsButtonView = settingsView
        }

        func updateSettings(_ settings: DashboardSettings) {
            settingsHostingVC?.rootView = SettingsPanelView(settings: settings)
        }

        private func makeSettingsButton(titlebarContainer: NSView, settings: DashboardSettings) -> NSView {
            let hostingVC = NSHostingController<SettingsPanelView>(
                rootView: SettingsPanelView(settings: settings)
            )
            settingsHostingVC = hostingVC

            let pop = NSPopover()
            pop.behavior = .transient
            pop.animates = true
            pop.contentViewController = hostingVC
            popover = pop

            let button = NSButton(frame: .zero)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.isBordered = false
            button.image = NSImage(systemSymbolName: "slider.horizontal.3",
                                   accessibilityDescription: "Dashboard settings")
            button.image?.isTemplate = true
            button.contentTintColor = .secondaryLabelColor
            button.target = self
            button.action = #selector(togglePopover(_:))
            return button
        }

        @objc private func togglePopover(_ sender: NSButton) {
            guard let pop = popover else { return }
            if pop.isShown {
                pop.close()
            } else {
                pop.show(relativeTo: sender.bounds, of: sender, preferredEdge: .maxY)
            }
        }
    }
}

// MARK: - Titlebar title view

/// Standalone AppKit view embedded in the titlebar container so the pulse animation
/// runs in Core Animation rather than inside SwiftUI's render loop.
final class TitlebarStatusView: NSView {
    private let label = NSTextField(labelWithString: "Performance")
    private let dotView = NSView(frame: .zero)

    override var intrinsicContentSize: NSSize {
        let labelSize = label.intrinsicContentSize
        return NSSize(width: labelSize.width + 13, height: max(labelSize.height, 6))
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor

        dotView.translatesAutoresizingMaskIntoConstraints = false
        dotView.wantsLayer = true
        dotView.layer?.backgroundColor = NSColor.systemGreen.cgColor
        dotView.layer?.cornerRadius = 3
        dotView.layer?.shadowColor = NSColor.systemGreen.withAlphaComponent(0.7).cgColor
        dotView.layer?.shadowRadius = 4
        dotView.layer?.shadowOpacity = 1
        dotView.layer?.shadowOffset = .zero

        addSubview(label)
        addSubview(dotView)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            dotView.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 7),
            dotView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dotView.centerYAnchor.constraint(equalTo: centerYAnchor),
            dotView.widthAnchor.constraint(equalToConstant: 6),
            dotView.heightAnchor.constraint(equalToConstant: 6)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        startPulseIfNeeded()
    }

    private func startPulseIfNeeded() {
        guard let dotLayer = dotView.layer, dotLayer.animation(forKey: "pulse") == nil else { return }

        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.3
        pulse.duration = 1.2
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        dotLayer.add(pulse, forKey: "pulse")
    }
}
