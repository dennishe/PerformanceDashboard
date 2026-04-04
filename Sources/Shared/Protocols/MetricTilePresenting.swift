/// Provides the data needed to render a `MetricTileView`.
///
/// View models conform so a single generic wrapper can display any metric tile
/// without enumerating concrete types in the dashboard layout.
@MainActor
public protocol MetricTilePresenting: AnyObject {
    var tileTitle: String { get }
    var tileValue: String { get }
    var tileGaugeValue: Double? { get }
    var tileHistory: [Double] { get }
    var tileThresholdLevel: ThresholdLevel { get }
    var tileSubtitle: String? { get }
    var tileSystemImage: String { get }
}
