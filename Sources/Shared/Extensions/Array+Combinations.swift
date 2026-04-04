// MARK: - Array+Combinations

extension Array {
    /// Returns all combinations of `size` elements from `self`, in lexicographic order.
    func combinations(size: Int) -> [[Element]] {
        guard size > 0, size <= count else { return size == 0 ? [[]] : [] }
        if size == count { return [self] }
        let rest = Array(dropFirst())
        return rest.combinations(size: size - 1).map { [self[0]] + $0 } + rest.combinations(size: size)
    }
}
