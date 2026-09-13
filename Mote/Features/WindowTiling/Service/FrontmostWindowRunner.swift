import AppKit
@preconcurrency import ApplicationServices

enum FrontmostWindowRunner {
    struct Snapshot {
        let element: AXUIElement
        let frame: CGRect
        let screen: CGRect
    }

    static func read() -> Snapshot? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let element = focusedWindow(in: appElement) ?? firstWindow(in: appElement)
        else { return nil }
        guard let axFrame = axFrame(of: element) else { return nil }
        let cocoa = cocoaFrame(fromAX: axFrame)
        let visibleFrames = NSScreen.screens.map(\.visibleFrame)
        let fallback = NSScreen.main?.visibleFrame ?? visibleFrames.first ?? .zero
        let screen = WindowTiling.preferredScreen(
            for: cocoa, among: visibleFrames, fallback: fallback)
        return Snapshot(element: element, frame: cocoa, screen: screen)
    }

    static func write(_ frame: CGRect, to element: AXUIElement) -> Bool {
        let ax = axFrame(fromCocoa: frame)
        setAXSize(ax.size, on: element)
        setAXPoint(ax.origin, on: element)
        return setAXSize(ax.size, on: element)
    }

    private static func focusedWindow(in app: AXUIElement) -> AXUIElement? {
        axElement(app, attribute: kAXFocusedWindowAttribute as CFString)
    }

    private static func firstWindow(in app: AXUIElement) -> AXUIElement? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
            == .success
        else { return nil }
        return (value as? [AXUIElement])?.first
    }

    private static func axElement(_ element: AXUIElement, attribute: CFString) -> AXUIElement? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
            return nil
        }
        guard let value, CFGetTypeID(value as CFTypeRef) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private static func axFrame(of element: AXUIElement) -> CGRect? {
        guard let origin = axPoint(element, kAXPositionAttribute as CFString),
            let size = axSize(element, kAXSizeAttribute as CFString)
        else { return nil }
        return CGRect(origin: origin, size: size)
    }

    private static func axPoint(_ element: AXUIElement, _ attribute: CFString) -> CGPoint? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            CFGetTypeID(value as CFTypeRef) == AXValueGetTypeID()
        else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private static func axSize(_ element: AXUIElement, _ attribute: CFString) -> CGSize? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
            CFGetTypeID(value as CFTypeRef) == AXValueGetTypeID()
        else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    @discardableResult
    private static func setAXPoint(_ point: CGPoint, on element: AXUIElement) -> Bool {
        var point = point
        guard let encoded = AXValueCreate(.cgPoint, &point) else { return false }
        return AXUIElementSetAttributeValue(
            element, kAXPositionAttribute as CFString, encoded) == .success
    }

    @discardableResult
    private static func setAXSize(_ size: CGSize, on element: AXUIElement) -> Bool {
        var size = size
        guard let encoded = AXValueCreate(.cgSize, &size) else { return false }
        return AXUIElementSetAttributeValue(
            element, kAXSizeAttribute as CFString, encoded) == .success
    }

    private static var primaryHeight: CGFloat {
        NSScreen.screens.first { $0.frame.origin == .zero }?.frame.height
            ?? NSScreen.screens.map(\.frame.maxY).max() ?? 0
    }

    private static func cocoaFrame(fromAX ax: CGRect) -> CGRect {
        CGRect(
            x: ax.origin.x,
            y: primaryHeight - ax.origin.y - ax.height,
            width: ax.width,
            height: ax.height)
    }

    private static func axFrame(fromCocoa cocoa: CGRect) -> CGRect {
        CGRect(
            x: cocoa.origin.x,
            y: primaryHeight - cocoa.origin.y - cocoa.height,
            width: cocoa.width,
            height: cocoa.height)
    }
}
