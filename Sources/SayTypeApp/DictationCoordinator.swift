import Foundation
import SayTypeCore

@MainActor
final class DictationCoordinator {
    private let dictationService = NativeDictationService()
    private let pasteService = PasteService()
    private let stateChanged: (SayTypeState) -> Void
    private var state: SayTypeState = .idle
    private var resetTask: Task<Void, Never>?

    init(stateChanged: @escaping (SayTypeState) -> Void) {
        self.stateChanged = stateChanged
        publish(.idle)
    }

    func toggleFromHotKey() {
        AppLog.write("hotkey delivered")
        performToggle(fromHotKey: true)
    }

    func toggle() {
        performToggle(fromHotKey: false)
    }

    private func performToggle(fromHotKey: Bool) {
        switch state.toggleAction(fromHotKey: fromHotKey) {
        case .showHotKeyThenStart:
            publish(.hotkeyReceived)
            Task { await startRecording() }
        case .start:
            Task { await startRecording() }
        case .stop:
            Task { await stopAndPaste() }
        case .ignore:
            break
        }
    }

    func setFailure(_ message: String) {
        publish(.failed(message: message))
    }

    private func startRecording() async {
        resetTask?.cancel()
        do {
            AppLog.write("start recording requested")
            publish(.preparing)
            try await PermissionPrompter.requestSpeechAuthorization()
            AppLog.write("speech permission ok")
            try await PermissionPrompter.requestMicrophoneAccess()
            AppLog.write("microphone permission ok")
            try await dictationService.start { [weak self] text in
                self?.publish(.recording(partialText: text))
            }
            AppLog.write("recording started")
            publish(.recording(partialText: ""))
        } catch {
            AppLog.write("start recording failed: \(friendly(error))")
            publish(.failed(message: friendly(error)))
        }
    }

    private func stopAndPaste() async {
        let partial = dictationService.currentText
        do {
            AppLog.write("stop recording requested")
            publish(.transcribing(partialText: partial))
            let text = try await dictationService.stop()
            AppLog.write("transcription finished chars=\(text.count)")
            guard !text.isEmpty else {
                publish(.finished(text: ""))
                scheduleReset()
                return
            }
            publish(.pasting(text: text))
            try await pasteService.copyAndPaste(text)
            AppLog.write("paste posted chars=\(text.count)")
            publish(.finished(text: text))
            scheduleReset()
        } catch {
            AppLog.write("stop recording failed: \(friendly(error))")
            publish(.failed(message: friendly(error)))
            await dictationService.cancel()
        }
    }

    private func publish(_ newState: SayTypeState) {
        state = newState
        stateChanged(newState)
    }

    private func scheduleReset() {
        resetTask?.cancel()
        resetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                self?.publish(.idle)
            }
        }
    }

    private func friendly(_ error: Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            description
        } else {
            error.localizedDescription
        }
    }
}
