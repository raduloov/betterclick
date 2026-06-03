import CoreGraphics
import Foundation
import BetterClickCore

/// Listen-only global tap for mouse-down events. Emits a `MouseButton`
/// for each press without delaying or modifying the click.
final class ClickTap {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let onPress: (MouseButton) -> Void

    init(onPress: @escaping (MouseButton) -> Void) {
        self.onPress = onPress
    }

    /// Returns false if the tap could not be created (missing permission).
    @discardableResult
    func start() -> Bool {
        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<ClickTap>.fromOpaque(refcon).takeUnretainedValue()
            me.handle(type: type, event: event)
            return Unmanaged.passUnretained(event)   // pass through unchanged
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        else {
            return false
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        // Re-enable if the system disabled the tap (e.g. timeout).
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let number = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        guard let button = MouseButton(cgButtonNumber: number) else { return }
        onPress(button)
    }
}
