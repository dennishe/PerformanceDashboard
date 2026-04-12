import SwiftUI

struct HostedBatteryTileContentRepresentable: NSViewRepresentable, Equatable {
    let model: BatteryTileModel

    func makeNSView(context: Context) -> HostedBatteryTileContentView {
        HostedBatteryTileContentView()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: HostedBatteryTileContentView,
        context: Context
    ) -> CGSize? {
        CGSize(
            width: proposal.width ?? nsView.bounds.width,
            height: MetricTileLayoutMetrics.contentHeight
        )
    }

    func updateNSView(_ nsView: HostedBatteryTileContentView, context: Context) {
        nsView.update(model: model, displayScale: context.environment.displayScale)
    }
}
