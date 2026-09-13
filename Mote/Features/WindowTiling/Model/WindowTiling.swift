import CoreGraphics
import Foundation

enum WindowTileSize: Int, CaseIterable, Equatable {
    case third, half, twoThirds, full

    var nextLarger: WindowTileSize? {
        switch self {
        case .third: return .half
        case .half: return .twoThirds
        case .twoThirds: return .full
        case .full: return nil
        }
    }

    var nextSmaller: WindowTileSize? {
        switch self {
        case .full: return .twoThirds
        case .twoThirds: return .half
        case .half: return .third
        case .third: return nil
        }
    }
}

enum WindowTileAlign: Int, CaseIterable, Equatable {
    case left, center, right
}

struct WindowTileState: Equatable {
    var size: WindowTileSize
    var align: WindowTileAlign
    static let full = WindowTileState(size: .full, align: .left)
    var isFull: Bool { size == .full }
}

enum WindowTiling {
    private static let sizeRatioTolerance: CGFloat = 0.08

    static func state(of window: CGRect, in screen: CGRect) -> WindowTileState {
        guard screen.width > 1 else { return .full }
        let inset = spaceThreshold(in: screen)
        let leftGap = window.minX - screen.minX
        let rightGap = screen.maxX - window.maxX
        let widthRatio = window.width / screen.width
        if leftGap <= inset && rightGap <= inset { return .full }
        if widthRatio >= 0.88 { return .full }
        let size: WindowTileSize
        if widthRatio >= 0.58 { size = .twoThirds }
        else if widthRatio >= 0.42 { size = .half }
        else { size = .third }
        let align: WindowTileAlign
        if leftGap <= inset { align = .left }
        else if rightGap <= inset { align = .right }
        else { align = .center }
        return WindowTileState(size: size, align: align)
    }

    static func resized(
        _ state: WindowTileState, window: CGRect, screen: CGRect
    ) -> WindowTileState {
        if state.size == .third && state.align == .right { return .full }
        let inset = spaceThreshold(in: screen)
        let spaceOnRight = screen.maxX - window.maxX > inset
        let spaceOnLeft = window.minX - screen.minX > inset
        if state.isFull || (!spaceOnRight && !spaceOnLeft) {
            return WindowTileState(size: .twoThirds, align: .right)
        }
        if spaceOnRight { return expandRight(state) }
        return shrinkKeepingRight(state)
    }

    static func moved(_ state: WindowTileState) -> WindowTileState {
        guard !state.isFull else { return state }
        switch state.align {
        case .right: return WindowTileState(size: state.size, align: .center)
        case .center: return WindowTileState(size: state.size, align: .left)
        case .left: return WindowTileState(size: state.size, align: .right)
        }
    }

    static func rect(for state: WindowTileState, in screen: CGRect) -> CGRect {
        if state.isFull { return screen }
        let third = floor(screen.width / 3.0)
        let half = floor(screen.width / 2.0)
        let twoThirds = screen.width - third
        let width: CGFloat
        switch state.size {
        case .third: width = third
        case .half: width = half
        case .twoThirds: width = twoThirds
        case .full: return screen
        }
        let x: CGFloat
        switch state.align {
        case .left: x = screen.minX
        case .right: x = screen.maxX - width
        case .center:
            switch state.size {
            case .third: x = screen.minX + third
            case .half: x = screen.minX + floor((screen.width - half) / 2.0)
            case .twoThirds: x = screen.minX + floor((screen.width - twoThirds) / 2.0)
            case .full: x = screen.minX
            }
        }
        return CGRect(x: x, y: screen.minY, width: width, height: screen.height)
    }

    static func preferredScreen(
        for window: CGRect, among screens: [CGRect], fallback: CGRect
    ) -> CGRect {
        let best = screens.max { a, b in
            area(a.intersection(window)) < area(b.intersection(window))
        }
        guard let best, best.intersects(window) else { return fallback }
        return best
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        max(0, rect.width) * max(0, rect.height)
    }

    private static func expandRight(_ state: WindowTileState) -> WindowTileState {
        let left = leftFraction(state)
        var size = state.size
        while let next = size.nextLarger {
            size = next
            if size == .full { return .full }
            if let align = exactAlign(left: left, size: size) {
                return WindowTileState(size: size, align: align)
            }
        }
        return .full
    }

    private static func shrinkKeepingRight(_ state: WindowTileState) -> WindowTileState {
        guard let smaller = state.size.nextSmaller else { return .full }
        return WindowTileState(size: smaller, align: .right)
    }

    private static func leftFraction(_ state: WindowTileState) -> CGFloat {
        if state.isFull { return 0 }
        switch (state.size, state.align) {
        case (_, .left): return 0
        case (.third, .center): return 1.0 / 3.0
        case (.third, .right): return 2.0 / 3.0
        case (.half, .center): return 0.25
        case (.half, .right): return 0.5
        case (.twoThirds, .center): return 1.0 / 6.0
        case (.twoThirds, .right): return 1.0 / 3.0
        default: return 0
        }
    }

    private static func exactAlign(left: CGFloat, size: WindowTileSize) -> WindowTileAlign? {
        for align in WindowTileAlign.allCases {
            let candidate = WindowTileState(size: size, align: align)
            if abs(leftFraction(candidate) - left) <= sizeRatioTolerance { return align }
        }
        return nil
    }

    private static func spaceThreshold(in screen: CGRect) -> CGFloat {
        max(40, screen.width * 0.08)
    }
}
