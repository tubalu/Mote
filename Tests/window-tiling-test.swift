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
        tileRightWalksTheChain()
        tileLeftWalksTheChain()
        offChainEntersAtTwoThirdsOnThatEdge()
        moveStepsTowardThePressedEdge()
        moveLeavesFullScreenUnchanged()
        detectsRightHalfFromGeometry()
        preferredScreenPicksLargestIntersection()
        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }

    static let leftHalf = WindowTileState(size: .half, align: .left)
    static let leftTwoThirds = WindowTileState(size: .twoThirds, align: .left)
    static let rightTwoThirds = WindowTileState(size: .twoThirds, align: .right)
    static let rightHalf = WindowTileState(size: .half, align: .right)

    static func tileRightWalksTheChain() {
        var state = leftHalf
        state = WindowTiling.tiled(state, toward: .right)
        expect(state == leftTwoThirds, "left 1/2 + → → left 2/3")
        state = WindowTiling.tiled(state, toward: .right)
        expect(state == rightTwoThirds, "left 2/3 + → → right 2/3")
        state = WindowTiling.tiled(state, toward: .right)
        expect(state == rightHalf, "right 2/3 + → → right 1/2")
        state = WindowTiling.tiled(state, toward: .right)
        expect(state == rightHalf, "right 1/2 + → stays")
    }

    static func tileLeftWalksTheChain() {
        var state = rightHalf
        state = WindowTiling.tiled(state, toward: .left)
        expect(state == rightTwoThirds, "right 1/2 + ← → right 2/3")
        state = WindowTiling.tiled(state, toward: .left)
        expect(state == leftTwoThirds, "right 2/3 + ← → left 2/3")
        state = WindowTiling.tiled(state, toward: .left)
        expect(state == leftHalf, "left 2/3 + ← → left 1/2")
        state = WindowTiling.tiled(state, toward: .left)
        expect(state == leftHalf, "left 1/2 + ← stays")
    }

    static func offChainEntersAtTwoThirdsOnThatEdge() {
        let offChain: [(WindowTileState, String)] = [
            (.full, "full"),
            (WindowTileState(size: .third, align: .center), "center 1/3"),
            (WindowTileState(size: .third, align: .left), "left 1/3"),
            (WindowTileState(size: .half, align: .center), "center 1/2"),
        ]
        for (state, name) in offChain {
            expect(WindowTiling.tiled(state, toward: .left) == leftTwoThirds, "\(name) + ← → left 2/3")
            expect(
                WindowTiling.tiled(state, toward: .right) == rightTwoThirds,
                "\(name) + → → right 2/3")
        }
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
