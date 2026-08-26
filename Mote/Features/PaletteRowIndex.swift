import Foundation

/// What a flat selection index resolves to. Section headers aren't selectable and take no index.
enum PaletteRow: Equatable {
    case element(section: Int, offset: Int)
}

/// A screen's visible row order: each section's rows, contiguous and in section order.
struct PaletteRowIndex: Equatable {
    let sectionCounts: [Int]

    init(sectionCounts: [Int]) {
        self.sectionCounts = sectionCounts
    }

    var count: Int { sectionCounts.reduce(0, +) }

    /// The selection the screen actually highlights: out-of-range values clamp into the results.
    func clamped(_ selection: Int) -> Int {
        count == 0 ? 0 : min(max(selection, 0), count - 1)
    }

    func row(at index: Int) -> PaletteRow? {
        guard index >= 0, index < count else { return nil }
        var offset = index
        for (section, sectionCount) in sectionCounts.enumerated() {
            if offset < sectionCount { return .element(section: section, offset: offset) }
            offset -= sectionCount
        }
        return nil
    }

    /// The inverse of `row(at:)` — where a screen puts the highlight after its own list moves.
    func index(section: Int, offset: Int) -> Int? {
        guard sectionCounts.indices.contains(section), offset >= 0,
            offset < sectionCounts[section]
        else { return nil }
        let preceding = sectionCounts[..<section].reduce(0, +)
        return preceding + offset
    }
}
