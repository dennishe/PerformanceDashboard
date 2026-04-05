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

            let hosting = NSHostingView(rootView: TitlebarTitleView())
            hosting.translatesAutoresizingMaskIntoConstraints = false
            titlebarContainer.addSubview(hosting)
            NSLayoutConstraint.activate([
                hosting.centerYAnchor.constraint(equalTo: titlebarContainer.centerYAnchor),
                hosting.leadingAnchor.constraint(equalTo: titlebarContainer.leadingAnchor,
                                                 constant: 76)
            ])
            injectedView = hosting
        }
    }
}

// MARK: - Titlebar title view

/// Standalone SwiftUI view embedded in the AppKit titlebar container.
private struct TitlebarTitleView: View {
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 7) {
            Text("Performance")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .shadow(color: .green.opacity(0.7), radius: 4)
                .opacity(isPulsing ? 0.3 : 1.0)
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: isPulsing
                )
                .onAppear { isPulsing = true }
        }
    }
}

#Preview {
    let services = ServiceContainer()
    return DashboardView(services: services)
}
