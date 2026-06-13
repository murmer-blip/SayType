import Foundation

public enum SayTypeState: Equatable, Sendable {
    case idle
    case hotkeyReceived
    case preparing
    case recording(partialText: String)
    case transcribing(partialText: String)
    case pasting(text: String)
    case finished(text: String)
    case failed(message: String)

    public var isBusy: Bool {
        switch self {
        case .idle, .finished, .failed:
            false
        case .hotkeyReceived, .preparing, .recording, .transcribing, .pasting:
            true
        }
    }

    public var statusText: String {
        switch self {
        case .idle:
            "Ready"
        case .hotkeyReceived:
            "Hotkey pressed"
        case .preparing:
            "Preparing speech model"
        case let .recording(partialText):
            partialText.isEmpty ? "Recording" : "Recording: \(partialText)"
        case let .transcribing(partialText):
            partialText.isEmpty ? "Finishing transcript" : "Finishing: \(partialText)"
        case .pasting:
            "Pasting"
        case .finished:
            "Pasted"
        case let .failed(message):
            message
        }
    }
}

public enum SayTypeToggleAction: Equatable, Sendable {
    case showHotKeyThenStart
    case start
    case stop
    case ignore
}

public extension SayTypeState {
    func toggleAction(fromHotKey: Bool) -> SayTypeToggleAction {
        switch self {
        case .idle, .finished, .failed:
            fromHotKey ? .showHotKeyThenStart : .start
        case .recording:
            .stop
        case .hotkeyReceived, .preparing, .transcribing, .pasting:
            .ignore
        }
    }
}
