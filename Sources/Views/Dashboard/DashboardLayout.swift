import SwiftUI

// MARK: - Wide Eligibility

private struct WideEligibleKey: LayoutValueKey {
    static let defaultValue = false
}

extension View {
    /// Marks a tile as eligible to grow to two columns when the layout needs to fill the last row.
    func wideEligible() -> some View {
        layoutValue(key: WideEligibleKey.self, value: true)
    }
}

// MARK: - DashboardLayout

/// Adaptive grid that promotes wide-eligible tiles to span two columns so the last row is always full.
/// The number of columns is derived from the container width and `minTileWidth`.
/// Eligible tiles are tried in all combinations (lex order) until simulation confirms no reflow gap;
/// non-eligible tiles are used as fallback when there are not enough eligible ones.
struct DashboardLayout: Layout {
    var spacing: CGFloat = 12
    var minTileWidth: CGFloat = 200
    var padding: CGFloat = 16

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let width = proposal.width ?? 800
        let avail = max(0, width - 2 * padding)
        let cols = columnCount(for: avail)
        let spans = assignSpans(subviews: subviews, columns: cols)
        let tW = tileWidth(containerWidth: avail, cols: cols)
        let heights = rowHeights(subviews: subviews, spans: spans, tileW: tW, columns: cols)
        let tileH = heights.reduce(0, +) + CGFloat(max(heights.count - 1, 0)) * spacing
        return CGSize(width: width, height: tileH + 2 * padding)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let avail = max(0, bounds.width - 2 * padding)
        let cols = columnCount(for: avail)
        let tileW = tileWidth(containerWidth: avail, cols: cols)
        let spans = assignSpans(subviews: subviews, columns: cols)
        let heights = rowHeights(subviews: subviews, spans: spans, tileW: tileW, columns: cols)
        var col = 0, row = 0
        var rowY = bounds.minY + padding
        for (index, subview) in subviews.enumerated() {
            let span = spans[index]
            if col + span > cols { rowY += heights[row] + spacing; col = 0; row += 1 }
            let tileW2 = CGFloat(span) * tileW + CGFloat(span - 1) * spacing
            subview.place(
                at: CGPoint(x: bounds.minX + padding + CGFloat(col) * (tileW + spacing), y: rowY),
                proposal: ProposedViewSize(width: tileW2, height: heights[row])
            )
            col += span
            if col == cols { rowY += heights[row] + spacing; col = 0; row += 1 }
        }
    }
}

// MARK: - Private Helpers

private extension DashboardLayout {
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

    /// Returns all combinations of `size` elements from `array`, in lexicographic order.
    func combinations<T>(_ array: [T], size: Int) -> [[T]] {
        guard size > 0, size <= array.count else { return size == 0 ? [[]] : [] }
        if size == array.count { return [array] }
        let rest = Array(array.dropFirst())
        return combinations(rest, size: size - 1).map { [array[0]] + $0 } + combinations(rest, size: size)
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
            for combo in combinations(eligible, size: extra) {
                let spans = makeSpans(count: count, wide: Set(combo))
                if simulate(spans: spans, columns: columns) == columns { return spans }
            }
        }

        // Supplement with non-eligible tiles to reach exactly `extra` promotions.
        let nonEligible = (0..<count).filter { !eligible.contains($0) }
        let stillNeeded = extra - min(extra, eligible.count)
        if stillNeeded > 0 {
            let candidates = Array(nonEligible.prefix(8))
            for combo in combinations(candidates, size: min(stillNeeded, candidates.count)) {
                let promoted = Set(eligible).union(Set(combo))
                let spans = makeSpans(count: count, wide: promoted)
                if simulate(spans: spans, columns: columns) == columns { return spans }
            }
        }

        // Ultimate fallback: promote the first `extra` tiles (index 0 never causes reflow).
        return makeSpans(count: count, wide: Set((0..<count).prefix(extra)))
    }

    /// Computes the max tile height per row, respecting spans and reflow.
    func rowHeights(subviews: Subviews, spans: [Int], tileW: CGFloat, columns: Int) -> [CGFloat] {
        var heights: [CGFloat] = []
        var col = 0, rowMaxH: CGFloat = 0
        for (index, subview) in subviews.enumerated() {
            let span = spans[index]
            if col + span > columns { heights.append(rowMaxH); col = 0; rowMaxH = 0 }
            let width = CGFloat(span) * tileW + CGFloat(span - 1) * spacing
            rowMaxH = max(rowMaxH, subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height)
            col += span
            if col == columns { heights.append(rowMaxH); rowMaxH = 0; col = 0 }
        }
        if rowMaxH > 0 { heights.append(rowMaxH) }
        return heights
    }
}
