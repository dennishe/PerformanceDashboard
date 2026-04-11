import SwiftUI

enum HostedNetworkTileLayout {
    static let headerHeight = MetricTileLayoutMetrics.ringGaugeSize
    static let sparklineHeight = SparklineGeometry.displayHeight
    static let iconSize: CGFloat = 14
    static let arrowWidth: CGFloat = 14
}

enum HostedNetworkTileStyles {
    static let title = LayerTextStyle.tileCaption()
    static let downloadArrow = LayerTextStyle.tileBody(color: .systemGreen)
    static let uploadArrow = LayerTextStyle.tileBody(color: .systemBlue)
    static let body = LayerTextStyle.tileBody()
}

struct HostedNetworkTileContentRepresentable: NSViewRepresentable, Equatable {
    let tileModel: MetricTileModel
    let inTileModel: MetricTileModel
    let outTileModel: MetricTileModel

    func makeNSView(context: Context) -> HostedNetworkTileContentView {
        HostedNetworkTileContentView()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: HostedNetworkTileContentView,
        context: Context
    ) -> CGSize? {
        CGSize(width: proposal.width ?? nsView.bounds.width, height: MetricTileLayoutMetrics.contentHeight)
    }

    func updateNSView(_ nsView: HostedNetworkTileContentView, context: Context) {
        nsView.update(
            tileModel: tileModel,
            inTileModel: inTileModel,
            outTileModel: outTileModel,
            displayScale: context.environment.displayScale
        )
    }
}
