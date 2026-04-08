import Foundation

/// View models conforming to this protocol expose a rich snapshot for the detail sheet.
///
/// OCP: new metrics add a conformance here without touching any existing view.
@MainActor
public protocol DetailPresenting: AnyObject {
    var detailModel: DetailModel { get }
}
