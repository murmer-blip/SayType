import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

enum PasteError: LocalizedError {
    case accessibilityRequired
    case eventCreationFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityRequired:
            "Grant Accessibility to SayType so it can paste."
        case .eventCreationFailed:
            "Could not create the paste keyboard event."
        }
    }
}

@MainActor
final class PasteService {
    func copyAndPaste(_ text: String) async throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard AXIsProcessTrusted() else {
            PermissionPrompter.promptForAccessibility()
            throw PasteError.accessibilityRequired
        }

        try await Task.sleep(for: .milliseconds(120))
        try postCommandV()
    }

    private func postCommandV() throws {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw PasteError.eventCreationFailed
        }

        let commandKey = CGKeyCode(55)
        let vKey = CGKeyCode(9)
        let events: [(CGKeyCode, Bool, CGEventFlags)] = [
            (commandKey, true, .maskCommand),
            (vKey, true, .maskCommand),
            (vKey, false, .maskCommand),
            (commandKey, false, []),
        ]

        for (key, down, flags) in events {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else {
                throw PasteError.eventCreationFailed
            }
            event.flags = flags
            event.post(tap: .cghidEventTap)
            usleep(20_000)
        }
    }
}
