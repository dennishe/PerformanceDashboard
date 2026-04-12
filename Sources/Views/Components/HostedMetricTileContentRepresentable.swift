import SwiftUI

struct HostedMetricTileContentRepresentable: NSViewRepresentable, Equatable {
    let model: MetricTileModel

    func makeNSView(context: Context) -> HostedMetricTileContentView {
        HostedMetricTileContentView()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: HostedMetricTileContentView,
        context: Context
    ) -> CGSize? {
        CGSize(
            width: proposal.width ?? nsView.bounds.width,
            height: MetricTileLayoutMetrics.contentHeight
        )
    }

    func updateNSView(_ nsView: HostedMetricTileContentView, context: Context) {
        nsView.update(model: model, displayScale: context.environment.displayScale)
    }
}
