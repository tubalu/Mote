import Foundation

@main
@MainActor
struct PaletteRowIndexTests {
    static var failures = 0
    static var passes = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func expect(_ actual: PaletteRow?, _ expected: PaletteRow?, _ message: String) {
        expect(
            actual == expected,
            "\(message) — got \(String(describing: actual)), want \(String(describing: expected))")
    }

    static func expect(_ actual: Int?, _ expected: Int?, _ message: String) {
        expect(
            actual == expected,
            "\(message) — got \(String(describing: actual)), want \(String(describing: expected))")
    }

    /// Every index resolves, and resolving then inverting returns the index it started from.
    static func expectRoundTrip(_ index: PaletteRowIndex, _ label: String) {
        for flat in 0..<index.count {
            guard let row = index.row(at: flat) else {
                expect(false, "\(label): index \(flat) resolves to a row")
                continue
            }
            guard case .element(let section, let offset) = row else {
                expect(false, "\(label): unexpected row \(row)")
                continue
            }
            expect(
                index.index(section: section, offset: offset), flat,
                "\(label): section \(section) offset \(offset) inverts to \(flat)")
        }
    }

    static func main() {
        let empty = PaletteRowIndex(sectionCounts: [])
        expect(empty.count == 0, "an empty screen has no rows")
        expect(empty.row(at: 0), nil, "an empty screen resolves no index")
        expect(empty.clamped(0) == 0, "the clamp holds at zero with no rows")
        expect(empty.clamped(7) == 0, "an out-of-range selection clamps to zero with no rows")
        expect(empty.index(section: 0, offset: 0), nil, "an empty screen has no section 0")

        let allEmptySections = PaletteRowIndex(sectionCounts: [0, 0, 0])
        expect(allEmptySections.count == 0, "empty sections contribute no rows")
        expect(allEmptySections.row(at: 0), nil, "empty sections resolve no index")

        let single = PaletteRowIndex(sectionCounts: [3])
        expect(single.count == 3, "one section of 3 is 3 rows")
        expect(single.row(at: 0), .element(section: 0, offset: 0), "index 0 is the first result")
        expect(single.row(at: 1), .element(section: 0, offset: 1), "index 1 is the second result")
        expect(single.row(at: 2), .element(section: 0, offset: 2), "index 2 is the last result")
        expect(single.row(at: 3), nil, "one past the end resolves to nothing")
        expect(single.row(at: -1), nil, "a negative index resolves to nothing")
        expectRoundTrip(single, "single section")

        let sections = PaletteRowIndex(sectionCounts: [2, 1, 3])
        expect(sections.count == 6, "three sections of 2, 1 and 3 are 6 selectable rows")
        expect(sections.row(at: 1), .element(section: 0, offset: 1), "the first section's last row")
        expect(
            sections.row(at: 2), .element(section: 1, offset: 0),
            "the next index crosses into the second section, skipping its header")
        expect(
            sections.row(at: 3), .element(section: 2, offset: 0),
            "a one-row section is crossed in a single step")
        expect(sections.row(at: 5), .element(section: 2, offset: 2), "the final row of the last section")
        expect(sections.row(at: 6), nil, "one past the last section resolves to nothing")
        expectRoundTrip(sections, "three sections")

        let gapped = PaletteRowIndex(sectionCounts: [2, 0, 2])
        expect(gapped.count == 4, "an empty section contributes no rows")
        expect(
            gapped.row(at: 2), .element(section: 2, offset: 0),
            "an empty section is stepped over, not landed in")
        expect(gapped.index(section: 1, offset: 0), nil, "an empty section has no valid offset")
        expectRoundTrip(gapped, "empty middle section")

        // Favorites, Applications, System Settings, System Actions, Commands.
        let launcherSections = PaletteRowIndex(sectionCounts: [3, 12, 5, 8, 2])
        expect(launcherSections.sectionCounts.count == 5, "the empty-query launcher has five sections")
        expect(launcherSections.count == 30, "every section's rows are selectable, its header is not")
        expect(
            launcherSections.row(at: 0), .element(section: 0, offset: 0),
            "a pinned favourite is the first row of the whole list")
        expect(
            launcherSections.row(at: 3), .element(section: 1, offset: 0),
            "Applications begins where Favorites ends, with no index spent on the header")
        expect(launcherSections.index(section: 4, offset: 1), 29, "the last command is the last index")
        expectRoundTrip(launcherSections, "launcher five sections")

        let launcherNoFavorites = PaletteRowIndex(sectionCounts: [0, 12, 5, 8, 2])
        expect(
            launcherNoFavorites.row(at: 0), .element(section: 1, offset: 0),
            "an empty Favorites section is stepped over, not landed in")
        expectRoundTrip(launcherNoFavorites, "launcher without favourites")

        let launcherHidden = PaletteRowIndex(sectionCounts: [3, 12, 0, 8, 2])
        expect(launcherHidden.count == 25, "a hidden category contributes no rows")
        expect(
            launcherHidden.row(at: 15), .element(section: 3, offset: 0),
            "System Actions follows Applications once System Settings is hidden")
        expectRoundTrip(launcherHidden, "launcher with hidden categories")

        // A typed query collapses sections into one Results list.
        let launcherQuery = PaletteRowIndex(sectionCounts: [9])
        expect(launcherQuery.count == 9, "nine ranked matches")
        expect(
            launcherQuery.row(at: 0), .element(section: 0, offset: 0),
            "the best-ranked match leads")
        expectRoundTrip(launcherQuery, "launcher query results")

        for section in 0..<5 {
            var only = [Int](repeating: 0, count: 5)
            only[section] = 3
            let alone = PaletteRowIndex(sectionCounts: only)
            expect(
                alone.index(section: section, offset: 0), 0,
                "section \(section) alone starts at the head of the list")
            expectRoundTrip(alone, "only section \(section)")
            var missing = [Int](repeating: 2, count: 5)
            missing[section] = 0
            let missingIndex = PaletteRowIndex(sectionCounts: missing)
            expect(missingIndex.count == 8, "hiding section \(section) drops exactly its rows")
            expect(
                missingIndex.index(section: section, offset: 0), nil,
                "section \(section) has no rows")
            expectRoundTrip(missingIndex, "section \(section) hidden")
        }

        for index in [single, sections, gapped, launcherSections] {
            expect(index.clamped(-1) == 0, "a selection below zero clamps to the first row")
            expect(index.clamped(-99) == 0, "a far-negative selection clamps to the first row")
            expect(
                index.clamped(index.count) == index.count - 1,
                "a selection one past the end clamps to the last row")
            expect(
                index.clamped(index.count + 50) == index.count - 1,
                "a far-past-the-end selection clamps to the last row")
            expect(
                index.row(at: index.clamped(Int.max)) != nil,
                "a clamped selection always resolves to a row")
            expect(
                index.row(at: index.clamped(Int.min)) != nil,
                "a clamped negative selection always resolves to a row")
        }

        expect(sections.index(section: 3, offset: 0), nil, "there is no fourth section")
        expect(sections.index(section: -1, offset: 0), nil, "there is no section before the first")
        expect(sections.index(section: 0, offset: 2), nil, "an offset past a section's rows is nothing")
        expect(sections.index(section: 0, offset: -1), nil, "a negative offset is nothing")

        for a in 0...3 {
            for b in 0...3 {
                for c in 0...3 {
                    let index = PaletteRowIndex(sectionCounts: [a, b, c])
                    let label = "shape [\(a),\(b),\(c)]"
                    expect(index.count == a + b + c, "\(label): the row count is every section")
                    expectRoundTrip(index, label)
                    let rows = (0..<index.count).compactMap(index.row(at:))
                    expect(
                        Set(rows.map(String.init(describing:))).count == rows.count,
                        "\(label): no two indices resolve to the same row")
                }
            }
        }

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }
}
