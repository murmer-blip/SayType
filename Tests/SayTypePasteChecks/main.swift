import AppKit
import Foundation

@main
struct SayTypePasteChecks {
    enum CheckError: Error { case failed(String), simulatedPasteFailure }

    @MainActor
    static func main() async throws {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }

        func expect(_ condition: Bool, _ message: String) throws {
            if !condition { throw CheckError.failed(message) }
        }
        func seed(_ text: String) {
            board.clearContents()
            board.setString(text, forType: .string)
        }
        func service(
            waitBeforePaste: @escaping () async throws -> Void = {},
            _ paste: @escaping () throws -> Void
        ) -> PasteService {
            PasteService(pasteboard: board, isAccessibilityTrusted: { true }, sendPaste: paste, waitBeforePaste: waitBeforePaste)
        }

        seed("Previously copied text")
        try await service {
            try expect(board.string(forType: .string) == "Dictation", "Target must receive the dictation")
        }.copyAndPaste("Dictation")
        try expect(board.string(forType: .string) == "Previously copied text", "Dictation overwrote the user's clipboard")

        let richText = Data("{\\rtf1 Previously copied text}".utf8)
        let first = NSPasteboardItem()
        first.setString("Previously copied text", forType: .string)
        first.setData(richText, forType: .rtf)
        let second = NSPasteboardItem()
        second.setString("file:///tmp/example.txt", forType: .fileURL)
        board.clearContents()
        board.writeObjects([first, second])
        try await service {}.copyAndPaste("Dictation")
        try expect(board.pasteboardItems?.count == 2, "Preserve every clipboard item")
        try expect(board.pasteboardItems?[0].data(forType: .rtf) == richText, "Preserve rich text data")
        try expect(board.pasteboardItems?[1].string(forType: .fileURL) == "file:///tmp/example.txt", "Preserve file URLs")

        board.clearContents()
        try await service {}.copyAndPaste("Dictation")
        try expect(board.pasteboardItems?.isEmpty ?? true, "Restore an empty clipboard")

        seed("Original")
        try await service { seed("New copy") }.copyAndPaste("Dictation")
        try expect(board.string(forType: .string) == "New copy", "Never overwrite a newer copy")

        seed("Original")
        do {
            try await service { throw CheckError.simulatedPasteFailure }.copyAndPaste("Dictation")
            throw CheckError.failed("Expected simulated failure")
        } catch CheckError.simulatedPasteFailure {}
        try expect(board.string(forType: .string) == "Original", "Restore after a paste failure")

        seed("Original")
        let cancelled = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            try await service { throw CheckError.failed("Cancelled paste was sent") }.copyAndPaste("Dictation")
        }
        do {
            try await cancelled.value
            throw CheckError.failed("Expected cancellation")
        } catch is CancellationError {}
        try expect(board.string(forType: .string) == "Original", "Cancellation must preserve the clipboard")

        // Cancel at the real suspension boundary, after the clipboard was replaced.
        let duringPreparation = Task { @MainActor in
            try await service(waitBeforePaste: {
                try expect(board.string(forType: .string) == "Dictation", "Cancel only after replacing the clipboard")
                withUnsafeCurrentTask { $0?.cancel() }
                try await Task.sleep(for: .milliseconds(120))
            }) {
                throw CheckError.failed("Cancelled paste was sent")
            }.copyAndPaste("Dictation")
        }
        do {
            try await duringPreparation.value
            throw CheckError.failed("Expected cancellation during preparation")
        } catch is CancellationError {}
        try expect(board.string(forType: .string) == "Original", "Restore when cancelled after replacing the clipboard")

        let started = ContinuousClock.now
        var pastePostedAt = started
        try await Task { @MainActor in
            try await service {
                pastePostedAt = .now
                withUnsafeCurrentTask { $0?.cancel() }
            }.copyAndPaste("Dictation")
        }.value
        try expect(ContinuousClock.now - pastePostedAt >= .milliseconds(500), "Cancellation after Cmd+V must not shorten the read window")
        try expect(board.string(forType: .string) == "Original", "Restore after cancellation during the read window")

        do {
            try await service(waitBeforePaste: { seed("Copied during preparation") }) {
                throw CheckError.failed("Must not paste a newer user copy")
            }.copyAndPaste("Dictation")
            throw CheckError.failed("Expected clipboard change error")
        } catch PasteError.clipboardChanged {}
        try expect(board.string(forType: .string) == "Copied during preparation", "Preserve newer copies made before Cmd+V")
        print("SayTypePasteChecks: 9 checks passed")
    }
}
