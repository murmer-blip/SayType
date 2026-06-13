import AVFoundation
import ApplicationServices
import Foundation
import Speech

enum PermissionError: LocalizedError {
    case speechDenied
    case microphoneDenied

    var errorDescription: String? {
        switch self {
        case .speechDenied:
            "Grant Speech Recognition to SayType."
        case .microphoneDenied:
            "Grant Microphone access to SayType."
        }
    }
}

enum PermissionPrompter {
    static func requestSpeechAuthorization() async throws {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard status == .authorized else {
            throw PermissionError.speechDenied
        }
    }

    static func requestMicrophoneAccess() async throws {
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        guard granted else {
            throw PermissionError.microphoneDenied
        }
    }

    @discardableResult
    static func promptForAccessibility() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }
}
