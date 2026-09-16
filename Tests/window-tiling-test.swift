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
        tileRightShrinksFromFullAlongTheRightEdge()
        tileLeftShrinksFromFullAlongTheLeftEdge()
        notFlushJumpsToTwoThirdsOnThatEdge()
        moveStepsTowardThePressedEdge()
        moveLeavesFullScreenUnchanged()
        detectsRightHalfFromGeometry()
        preferredScreenPicksLargestIntersection()
        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static func tileRightShrinksFromFullAlongTheRightEdge() {
        var state = WindowTileState.full
        state = WindowTiling.tiled(state, toward: .right)
        expect(state == WindowTileState(size: .twoThirds, align: .right), "full → 2/3 right")
        state = WindowTiling.tiled(state, toward: .right)
        expect(state == WindowTileState(size: .half, align: .right), "2/3 right → 1/2 right")
        state = WindowTiling.tiled(state, toward: .right)
        expect(state == WindowTileState(size: .third, align: .right), "1/2 right → 1/3 right")
        state = WindowTiling.tiled(state, toward: .right)
        expect(state == .full, "1/3 right → full")
    }

    static func tileLeftShrinksFromFullAlongTheLeftEdge() {
        var state = WindowTileState.full
        state = WindowTiling.tiled(state, toward: .left)
        expect(state == WindowTileState(size: .twoThirds, align: .left), "full → 2/3 left")
        state = WindowTiling.tiled(state, toward: .left)
        expect(state == WindowTileState(size: .half, align: .left), "2/3 left → 1/2 left")
        state = WindowTiling.tiled(state, toward: .left)
        expect(state == WindowTileState(size: .third, align: .left), "1/2 left → 1/3 left")
        state = WindowTiling.tiled(state, toward: .left)
        expect(state == .full, "1/3 left → full")
    }

    static func notFlushJumpsToTwoThirdsOnThatEdge() {
        let centerThird = WindowTileState(size: .third, align: .center)
        expect(
            WindowTiling.tiled(centerThird, toward: .right)
                == WindowTileState(size: .twoThirds, align: .right),
            "center 1/3 + → → 2/3 right")
        expect(
            WindowTiling.tiled(centerThird, toward: .left)
                == WindowTileState(size: .twoThirds, align: .left),
            "center 1/3 + ← → 2/3 left")
        let leftHalf = WindowTileState(size: .half, align: .left)
        expect(
            WindowTiling.tiled(leftHalf, toward: .right)
                == WindowTileState(size: .twoThirds, align: .right),
            "left 1/2 + → → 2/3 right")
        let rightHalf = WindowTileState(size: .half, align: .right)
        expect(
            WindowTiling.tiled(rightHalf, toward: .left)
                == WindowTileState(size: .twoThirds, align: .left),
            "right 1/2 + ← → 2/3 left")
    }

    static func moveStepsTowardThePressedEdge() {
        var state = WindowTileState(size: .half, align: .right)
        state = WindowTiling.moved(state, toward: .left)
        expect(state == WindowTileState(size: .half, align: .center), "right + ← → center")
        state = WindowTiling.moved(state, toward: .left)
        expect(state == WindowTileState(size: .half, align: .left), "center + ← → left")
        state = WindowTiling.moved(state, toward: .left)
        expect(state == WindowTileState(size: .half, align: .left), "left + ← stays")
        state = WindowTiling.moved(state, toward: .right)
        expect(state == WindowTileState(size: .half, align: .center), "left + → → center")
        state = WindowTiling.moved(state, toward: .right)
        expect(state == WindowTileState(size: .half, align: .right), "center + → → right")
        state = WindowTiling.moved(state, toward: .right)
        expect(state == WindowTileState(size: .half, align: .right), "right + → stays")
    }

    static func moveLeavesFullScreenUnchanged() {
        expect(WindowTiling.moved(.full, toward: .left) == .full, "move left leaves full")
        expect(WindowTiling.moved(.full, toward: .right) == .full, "move right leaves full")
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
