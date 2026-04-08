import SwiftUI

// MARK: - DashboardLayout
/// Per-width layout result cached inside `DashboardLayout.Cache`.
struct DashboardLayoutEntry: Sendable {
    let columns: Int
    let tileWidth: CGFloat
    let spans: [Int]
    let rowHeightValues: [CGFloat]
}

/// Adaptive grid that promotes wide-eligible tiles to fill the last row without gaps.
/// Columns are derived from the container width and `minTileWidth`.
struct DashboardLayout: Layout {
    var spacing: CGFloat = 12
    var minTileWidth: CGFloat = 200
    var padding: CGFloat = 16
    var onContentHeightChange: (@MainActor @Sendable (CGFloat) -> Void)?

    // MARK: Cache

    struct Cache: Sendable {
        var subviewCount: Int = 0
        /// Stored so `updateCache` can detect when the density preset changed.
        var minTileWidth: CGFloat = 0
        // Keyed by available width so minSize probes never evict the display-width entry.
        var entries: [CGFloat: DashboardLayoutEntry] = [:]
        var lastReportedHeight: CGFloat?
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(subviewCount: subviews.count, minTileWidth: minTileWidth)
    }

    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        // Invalidate when subview count changes or when minTileWidth changes (density preset).
        if cache.subviewCount != subviews.count || cache.minTileWidth != minTileWidth {
            cache.entries = [:]
            cache.lastReportedHeight = nil
            cache.subviewCount = subviews.count
            cache.minTileWidth = minTileWidth
        }
    }

    // MARK: Layout

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let avail = max(0, (proposal.width ?? 800) - 2 * padding)
        populate(&cache, availableWidth: avail, subviews: subviews)
        guard let entry = cache.entries[avail] else { return .zero }
        return CGSize(width: avail + 2 * padding, height: totalHeight(for: entry))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        guard !subviews.isEmpty else { return }
        let avail = max(0, bounds.width - 2 * padding)
        populate(&cache, availableWidth: avail, subviews: subviews)
        guard let entry = cache.entries[avail], !entry.rowHeightValues.isEmpty else { return }
        reportContentHeightIfNeeded(totalHeight(for: entry), cache: &cache)
        var col = 0, row = 0
        var rowY = bounds.minY + padding
        for (index, subview) in subviews.enumerated() {
            let span = entry.spans[index]
            if col + span > entry.columns {
                guard row < entry.rowHeightValues.count else { break }
                rowY += entry.rowHeightValues[row] + spacing
                col = 0
                row += 1
            }
            guard row < entry.rowHeightValues.count else { break }
            let rowHeight = entry.rowHeightValues[row]
            let tileW2 = CGFloat(span) * entry.tileWidth + CGFloat(span - 1) * spacing
            subview.place(
                at: CGPoint(x: bounds.minX + padding + CGFloat(col) * (entry.tileWidth + spacing), y: rowY),
                proposal: ProposedViewSize(width: tileW2, height: rowHeight)
            )
            col += span
            if col == entry.columns {
                rowY += rowHeight + spacing
                col = 0
                row += 1
            }
        }
    }

    // Returning nil avoids SwiftUI's default explicitAlignment path calling placeSubviews again.
    func explicitAlignment(
        of guide: HorizontalAlignment, in bounds: CGRect,
        proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache
    ) -> CGFloat? { nil }
    func explicitAlignment(
        of guide: VerticalAlignment, in bounds: CGRect,
        proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache
    ) -> CGFloat? { nil }
}
private extension DashboardLayout {
    func totalHeight(for entry: DashboardLayoutEntry) -> CGFloat {
        entry.rowHeightValues.reduce(0, +)
            + CGFloat(max(entry.rowHeightValues.count - 1, 0)) * spacing
            + 2 * padding
    }

    func reportContentHeightIfNeeded(_ height: CGFloat, cache: inout Cache) {
        guard let onContentHeightChange else { return }
        let roundedHeight = height.rounded(.up)
        if let lastReportedHeight = cache.lastReportedHeight,
           abs(lastReportedHeight - roundedHeight) < 0.5 {
            return
        }
        cache.lastReportedHeight = roundedHeight
        Task { @MainActor in
            onContentHeightChange(roundedHeight)
        }
    }

    /// Fills (or reuses) the cache entry for the given available width.
    /// Entries are keyed by width so different size proposals never evict each other.
    func populate(_ cache: inout Cache, availableWidth: CGFloat, subviews: Subviews) {
        guard cache.entries[availableWidth] == nil else { return }
        let cols = columnCount(for: availableWidth)
        let tileW = tileWidth(containerWidth: availableWidth, cols: cols)
        let spans = assignSpans(subviews: subviews, columns: cols)
        cache.entries[availableWidth] = DashboardLayoutEntry(
            columns: cols,
            tileWidth: tileW,
            spans: spans,
            rowHeightValues: rowHeights(spans: spans, columns: cols)
        )
    }

    func columnCount(for width: CGFloat) -> Int {
        max(1, Int((width + spacing) / (minTileWidth + spacing)))
    }

    func tileWidth(containerWidth: CGFloat, cols: Int) -> CGFloat {
        (containerWidth - CGFloat(cols - 1) * spacing) / CGFloat(cols)
    }

    /// Simulates placement and returns the last row's fill count.
    /// A return value of `columns` indicates the last row is exactly full.
    func simulate(spans: [Int], columns: Int) -> Int {
        var col = 0
        for span in spans {
            if col + span > columns { col = 0 }
            col += span
            if col == columns { col = 0 }
        }
        return col == 0 ? columns : col
    }

    func makeSpans(count: Int, wide: Set<Int>) -> [Int] {
        (0..<count).map { wide.contains($0) ? 2 : 1 }
    }

    /// Assigns a column span (1 or 2) to each subview using the fill heuristic.
    ///
    /// Computes how many extra spans are needed to make the total divisible by `columns`,
    /// then tries all combinations of wide-eligible tiles (lex order, smallest indices first)
    /// and picks the first whose simulated placement fills the last row without gaps.
    /// Falls back to non-eligible tiles when there are not enough eligible ones.
    func assignSpans(subviews: Subviews, columns: Int) -> [Int] {
        let count = subviews.count
        let extra = (columns - count % columns) % columns
        guard extra > 0 else { return Array(repeating: 1, count: count) }

        let eligible = subviews.indices.filter { subviews[$0][WideEligibleKey.self] }

        // Try all combinations of eligible tiles, preferring smallest indices (CPU, GPU, Memory).
        if extra <= eligible.count {
            for combo in eligible.combinations(size: extra) {
                let spans = makeSpans(count: count, wide: Set(combo))
                if simulate(spans: spans, columns: columns) == columns { return spans }
            }
        }

        // Supplement with non-eligible tiles to reach exactly `extra` promotions.
        let nonEligible = (0..<count).filter { !eligible.contains($0) }
        let stillNeeded = extra - min(extra, eligible.count)
        if stillNeeded > 0 {
            let candidates = Array(nonEligible.prefix(8))
            for combo in candidates.combinations(size: min(stillNeeded, candidates.count)) {
                let promoted = Set(eligible).union(Set(combo))
                let spans = makeSpans(count: count, wide: promoted)
                if simulate(spans: spans, columns: columns) == columns { return spans }
            }
        }

        // Ultimate fallback: promote the first `extra` tiles (index 0 never causes reflow).
        return makeSpans(count: count, wide: Set((0..<count).prefix(extra)))
    }

    /// Metric tiles are intentionally fixed-height, so row height depends only on row count.
    func rowHeights(spans: [Int], columns: Int) -> [CGFloat] {
        Array(
            repeating: MetricTileLayoutMetrics.height,
            count: DashboardGridMetrics.rowCount(spans: spans, columns: columns)
        )
    }
}
