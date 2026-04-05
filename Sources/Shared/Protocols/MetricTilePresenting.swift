/// Provides the data needed to render a `MetricTileView`.
///
/// View models conform so a single generic wrapper can display any metric tile
/// without enumerating concrete types in the dashboard layout.
@MainActor
public protocol MetricTilePresenting: AnyObject {
    var tileModel: MetricTileModel { get }
}
