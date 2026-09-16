import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

enum PasteError: LocalizedError {
    case accessibilityRequired
    case eventCreationFailed
    case clipboardUnavailable
    case clipboardChanged

    var errorDescription: String? {
        switch self {
        case .accessibilityRequired:
            "Grant Accessibility to SayType so it can paste."
        case .eventCreationFailed:
            "Could not create the paste keyboard event."
        case .clipboardUnavailable:
            "Could not preserve the clipboard. Try dictating again."
        case .clipboardChanged:
            "The clipboard changed before SayType could paste. Try dictating again."
        }
    }
}

@MainActor
final class PasteService {
    private let pasteboard: NSPasteboard
    private let isAccessibilityTrusted: () -> Bool
    private let sendPaste: () throws -> Void
    private let waitBeforePaste: () async throws -> Void

    init(
        pasteboard: NSPasteboard = .general,
        isAccessibilityTrusted: @escaping () -> Bool = { AXIsProcessTrusted() },
        sendPaste: @escaping () throws -> Void = { try PasteService.postCommandV() },
        waitBeforePaste: @escaping () async throws -> Void = {
            try await Task.sleep(for: .milliseconds(120))
        }
    ) {
        self.pasteboard = pasteboard
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.sendPaste = sendPaste
        self.waitBeforePaste = waitBeforePaste
    }

    func copyAndPaste(_ text: String) async throws {
        guard isAccessibilityTrusted() else {
            PermissionPrompter.promptForAccessibility()
            throw PasteError.accessibilityRequired
        }

        try Task.checkCancellation()
        let originalChangeCount = pasteboard.changeCount
        // Materialize every representation before clearing the system clipboard.
        let savedItems = try (pasteboard.pasteboardItems ?? []).map { item in
            let saved = NSPasteboardItem()
            for type in item.types {
                guard let data = item.data(forType: type), saved.setData(data, forType: type) else {
                    throw PasteError.clipboardUnavailable
                }
            }
            return saved
        }
        guard pasteboard.changeCount == originalChangeCount else {
            throw PasteError.clipboardChanged
        }

        let temporaryChangeCount = pasteboard.clearContents()
        let didWrite = pasteboard.setString(text, forType: .string)
        defer {
            // A newer user copy takes precedence over our saved clipboard.
            if pasteboard.changeCount == temporaryChangeCount {
                pasteboard.clearContents()
                if !savedItems.isEmpty {
                    pasteboard.writeObjects(savedItems)
                }
            }
        }
        guard didWrite else { throw PasteError.clipboardUnavailable }

        try await waitBeforePaste()
        guard pasteboard.changeCount == temporaryChangeCount else {
            throw PasteError.clipboardChanged
        }
        try sendPaste()
        // Posting Cmd+V does not acknowledge when the target app reads the clipboard.
        // Keep the transcript available briefly, even if this task is cancelled.
        await withCheckedContinuation { continuation in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                continuation.resume()
            }
        }
    }

    private static func postCommandV() throws {
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
