import SwiftUI
import AppKit

/// Root dashboard view — all metrics visible without scrolling on wide displays.
struct DashboardView: View {
    let services: ServiceContainer

    @State private var contentHeight = Constants.dashboardMinimumContentHeight

    var body: some View {
        DashboardLayout(
            spacing: 12,
            minTileWidth: 220,
            onContentHeightChange: updateContentHeight
        ) {
            CPUTileView(viewModel: services.cpu).wideEligible()
            GPUTileView(viewModel: services.gpu).wideEligible()
            MemoryTileView(viewModel: services.memory).wideEligible()
            NetworkInTileView(viewModel: services.network)
            NetworkOutTileView(viewModel: services.network)
            DiskTileView(viewModel: services.disk)
            #if arch(arm64)
            ANETileView(viewModel: services.accelerator)
            MediaEngineTileView(viewModel: services.mediaEngine)
            #endif
            PowerTileView(viewModel: services.power)
            ThermalTileView(viewModel: services.thermal)
            FanTileView(viewModel: services.fan)
            BatteryTileView(viewModel: services.battery)
            WirelessTileView(viewModel: services.wireless)
        }
        .background(Color.dashboardBackground.ignoresSafeArea())
        .background(TitlebarConfigurator())
        .background(
            WindowHeightSizer(
                contentHeight: contentHeight,
                minContentHeight: Constants.dashboardMinimumContentHeight
            )
        )
    }

    @MainActor
    private func updateContentHeight(_ height: CGFloat) {
        let clampedHeight = max(Constants.dashboardMinimumContentHeight, height.rounded(.up))
        guard abs(contentHeight - clampedHeight) > 0.5 else { return }
        contentHeight = clampedHeight
    }
}

// MARK: - NSWindow configurator

/// Injects a SwiftUI title view directly into the AppKit titlebar container
/// (the superview of the traffic-light buttons) so it is always rendered as
/// part of the titlebar layer — never behind it.
@MainActor
private struct TitlebarConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { @MainActor in
            guard let window = view.window else { return }
            context.coordinator.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    @MainActor
    final class Coordinator {
        private var injectedView: NSView?

        func attach(to window: NSWindow) {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.backgroundColor = .windowBackgroundColor

            // The close button's superview is the NSTitlebarContainerView.
            // Adding our hosting view there puts it permanently in the titlebar
            // layer, unaffected by focus changes.
            guard let closeButton = window.standardWindowButton(.closeButton),
                  let titlebarContainer = closeButton.superview else { return }

            injectedView?.removeFromSuperview()

            let titleView = TitlebarStatusView()
            titlebarContainer.addSubview(titleView)
            NSLayoutConstraint.activate([
                titleView.centerYAnchor.constraint(equalTo: titlebarContainer.centerYAnchor),
                titleView.leadingAnchor.constraint(equalTo: titlebarContainer.leadingAnchor,
                                                   constant: 76)
            ])
            injectedView = titleView
        }
    }
}

// MARK: - Titlebar title view

/// Standalone AppKit view embedded in the titlebar container so the pulse animation
/// runs in Core Animation rather than inside SwiftUI's render loop.
private final class TitlebarStatusView: NSView {
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

#Preview {
    let services = ServiceContainer()
    return DashboardView(services: services)
}
