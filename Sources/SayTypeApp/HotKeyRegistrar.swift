import ApplicationServices
import AppKit
import CoreGraphics
import Foundation
import SayTypeCore

enum HotKeyError: LocalizedError {
    case accessibilityRequired
    case eventTapUnavailable

    var errorDescription: String? {
        switch self {
        case .accessibilityRequired:
            "Grant Accessibility to SayType so it can observe the hotkey."
        case .eventTapUnavailable:
            "Could not create the SayType keyboard event tap."
        }
    }
}

final class HotKeyRegistrar: @unchecked Sendable {
    private let spec: HotKeySpec
    private let action: @MainActor () -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(spec: HotKeySpec, action: @escaping @MainActor () -> Void) throws {
        guard AXIsProcessTrusted() else {
            PermissionPrompter.promptForAccessibility()
            throw HotKeyError.accessibilityRequired
        }

        self.spec = spec
        self.action = action

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: sayTypeEventTapCallback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            throw HotKeyError.eventTapUnavailable
        }

        eventTap = tap
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            throw HotKeyError.eventTapUnavailable
        }
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    deinit {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                AppLog.write("event tap re-enabled")
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
        guard keyCode == spec.carbonKeyCode, spec.matches(flags: event.flags) else {
            return Unmanaged.passUnretained(event)
        }

        Task { @MainActor in
            action()
        }
        return nil
    }
}

private func sayTypeEventTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }
    let registrar = Unmanaged<HotKeyRegistrar>.fromOpaque(userInfo).takeUnretainedValue()
    _ = proxy
    return registrar.handle(type: type, event: event)
}

private extension HotKeySpec {
    func matches(flags: CGEventFlags) -> Bool {
        let wantsCommand = carbonModifiers & 0x0100 != 0
        let wantsOption = carbonModifiers & 0x0800 != 0
        let wantsControl = carbonModifiers & 0x1000 != 0
        let wantsShift = carbonModifiers & 0x0200 != 0

        return flags.contains(.maskCommand) == wantsCommand
            && flags.contains(.maskAlternate) == wantsOption
            && flags.contains(.maskControl) == wantsControl
            && flags.contains(.maskShift) == wantsShift
    }
}
