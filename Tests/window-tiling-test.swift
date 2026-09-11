import CoreGraphics
import Foundation

@main
@MainActor
enum WindowTilingTests {
    static var failures = 0
    static var passes = 0
    static let screen = CGRect(x: 0, y: 0, width: 1200, height: 800)

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func main() {
        resizeShrinksFromFullAlongTheRightEdge()
        resizeExpandsFromLeftThirdTowardFull()
        moveCyclesRightCenterLeftAtTheSameSize()
        moveLeavesFullScreenUnchanged()
        centerThirdExpandsRightIntoRightTwoThirds()
        detectsRightHalfFromGeometry()
        preferredScreenPicksLargestIntersection()
        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static func resizeShrinksFromFullAlongTheRightEdge() {
        var state = WindowTileState.full
        var window = WindowTiling.rect(for: state, in: screen)
        state = WindowTiling.resized(state, window: window, screen: screen)
        expect(state == WindowTileState(size: .twoThirds, align: .right), "full → 2/3 right")
        window = WindowTiling.rect(for: state, in: screen)
        state = WindowTiling.resized(state, window: window, screen: screen)
        expect(state == WindowTileState(size: .half, align: .right), "2/3 right → 1/2 right")
        window = WindowTiling.rect(for: state, in: screen)
        state = WindowTiling.resized(state, window: window, screen: screen)
        expect(state == WindowTileState(size: .third, align: .right), "1/2 right → 1/3 right")
        window = WindowTiling.rect(for: state, in: screen)
        state = WindowTiling.resized(state, window: window, screen: screen)
        expect(state == .full, "1/3 right → full")
    }

    static func resizeExpandsFromLeftThirdTowardFull() {
        var state = WindowTileState(size: .third, align: .left)
        var window = WindowTiling.rect(for: state, in: screen)
        state = WindowTiling.resized(state, window: window, screen: screen)
        expect(state == WindowTileState(size: .half, align: .left), "left 1/3 → left 1/2")
        window = WindowTiling.rect(for: state, in: screen)
        state = WindowTiling.resized(state, window: window, screen: screen)
        expect(state == WindowTileState(size: .twoThirds, align: .left), "left 1/2 → left 2/3")
        window = WindowTiling.rect(for: state, in: screen)
        state = WindowTiling.resized(state, window: window, screen: screen)
        expect(state == .full, "left 2/3 → full")
    }

    static func moveCyclesRightCenterLeftAtTheSameSize() {
        var state = WindowTileState(size: .half, align: .right)
        state = WindowTiling.moved(state)
        expect(state == WindowTileState(size: .half, align: .center), "right → center")
        state = WindowTiling.moved(state)
        expect(state == WindowTileState(size: .half, align: .left), "center → left")
        state = WindowTiling.moved(state)
        expect(state == WindowTileState(size: .half, align: .right), "left → right")
    }

    static func moveLeavesFullScreenUnchanged() {
        expect(WindowTiling.moved(.full) == .full, "move leaves full unchanged")
    }

    static func centerThirdExpandsRightIntoRightTwoThirds() {
        let state = WindowTileState(size: .third, align: .center)
        let window = WindowTiling.rect(for: state, in: screen)
        let next = WindowTiling.resized(state, window: window, screen: screen)
        expect(next == WindowTileState(size: .twoThirds, align: .right), "center 1/3 → right 2/3")
    }

    static func detectsRightHalfFromGeometry() {
        let window = WindowTiling.rect(
            for: WindowTileState(size: .half, align: .right), in: screen)
        expect(
            WindowTiling.state(of: window, in: screen)
                == WindowTileState(size: .half, align: .right),
            "right half round-trips")
    }

    static func preferredScreenPicksLargestIntersection() {
        let left = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let right = CGRect(x: 1000, y: 0, width: 1000, height: 800)
        let window = CGRect(x: 900, y: 0, width: 400, height: 800)
        let picked = WindowTiling.preferredScreen(
            for: window, among: [left, right], fallback: left)
        expect(picked == right, "largest intersection wins")
        let miss = CGRect(x: 3000, y: 0, width: 100, height: 100)
        expect(
            WindowTiling.preferredScreen(for: miss, among: [left, right], fallback: left) == left,
            "no intersection → fallback")
    }
}
