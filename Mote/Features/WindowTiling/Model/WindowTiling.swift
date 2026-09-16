import CoreGraphics
import Foundation

enum WindowTileSize: Int, CaseIterable, Equatable {
    case third, half, twoThirds, full

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
    static func state(of window: CGRect, in screen: CGRect) -> WindowTileState {
        guard screen.width > 1 else { return .full }
        let inset = spaceThreshold(in: screen)
        let leftGap = window.minX - screen.minX
        let rightGap = screen.maxX - window.maxX
        if leftGap <= inset && rightGap <= inset { return .full }
        let size = tileSize(forWidthRatio: window.width / screen.width)
        if size == .full { return .full }
        let align: WindowTileAlign
        if leftGap <= inset { align = .left }
        else if rightGap <= inset { align = .right }
        else { align = .center }
        return WindowTileState(size: size, align: align)
    }

    static func tiled(_ state: WindowTileState, toward edge: WindowTileAlign) -> WindowTileState {
        guard edge != .center else { return state }
        if state.isFull || state.align == edge {
            return shrink(state, pinning: edge)
        }
        return WindowTileState(size: .twoThirds, align: edge)
    }

    static func moved(_ state: WindowTileState, toward edge: WindowTileAlign) -> WindowTileState {
        guard !state.isFull, edge != .center, state.align != edge else { return state }
        if state.align == .center {
            return WindowTileState(size: state.size, align: edge)
        }
        return WindowTileState(size: state.size, align: .center)
    }

    static func rect(for state: WindowTileState, in screen: CGRect) -> CGRect {
        if state.isFull { return screen }
        let third = floor(screen.width / 3.0)
        let width: CGFloat
        switch state.size {
        case .third: width = third
        case .half: width = floor(screen.width / 2.0)
        case .twoThirds: width = screen.width - third
        case .full: return screen
        }
        let x: CGFloat
        switch state.align {
        case .left: x = screen.minX
        case .right: x = screen.maxX - width
        case .center:
            if state.size == .third {
                x = screen.minX + width
            } else {
                x = screen.minX + floor((screen.width - width) / 2.0)
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

    private static func tileSize(forWidthRatio ratio: CGFloat) -> WindowTileSize {
        if ratio >= 0.88 { return .full }
        if ratio >= 0.58 { return .twoThirds }
        if ratio >= 0.42 { return .half }
        return .third
    }

    private static func shrink(_ state: WindowTileState, pinning edge: WindowTileAlign)
        -> WindowTileState
    {
        guard let smaller = state.size.nextSmaller else { return .full }
        return WindowTileState(size: smaller, align: edge)
    }

    private static func spaceThreshold(in screen: CGRect) -> CGFloat {
        max(40, screen.width * 0.08)
    }
}
