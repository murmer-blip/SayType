import Foundation
import SayTypeCore

@main
struct SayTypeCoreChecks {
    static func main() {
        checkTranscriptAssemblerReplacesVolatileTextUntilFinalized()
        checkTranscriptAssemblerKeepsFinalSegmentsAndCurrentVolatileTail()
        checkDomainVocabularyProvidesBuiltInHints()
        checkDomainVocabularyRewritesConfiguredPhrases()
        checkDomainVocabularyUsesReplaceJSONKey()
        checkSayTypeStatesExposeHumanStatusText()
        checkHotKeyToggleStartsFromIdleWithFeedback()
        checkHotKeyToggleStopsWhileRecording()
        checkMenuToggleStartsWithoutHotKeyFeedback()
        checkBusyToggleStatesIgnoreRepeatedToggle()
        checkDefaultHotKeyUsesOptionSpace()
        checkAudioInputSelectorPrefersBuiltInMicOverDefaultBluetooth()
        checkAudioInputSelectorFallsBackToDefaultPhysicalInput()
        checkAudioInputSelectorIgnoresOutputOnlyDevices()
        checkAudioInputSelectorUsesVirtualOnlyAsLastResort()
        print("SayTypeCoreChecks: 15 checks passed")
    }

    private static func checkTranscriptAssemblerReplacesVolatileTextUntilFinalized() {
        var assembler = TranscriptAssembler()

        assembler.accept(text: "hello wor", isFinal: false)
        expect(assembler.text == "hello wor")

        assembler.accept(text: "hello world", isFinal: false)
        expect(assembler.text == "hello world")

        assembler.accept(text: "hello world", isFinal: true)
        expect(assembler.text == "hello world")
    }

    private static func checkTranscriptAssemblerKeepsFinalSegmentsAndCurrentVolatileTail() {
        var assembler = TranscriptAssembler()

        assembler.accept(text: "hello world", isFinal: true)
        assembler.accept(text: "from say type", isFinal: false)

        expect(assembler.text == "hello world from say type")
    }

    private static func checkDomainVocabularyProvidesBuiltInHints() {
        let hints = DomainVocabulary.builtIn.recognitionHints

        expect(hints.contains("traderops"))
        expect(hints.contains("CLI"))
        expect(hints.count <= DomainVocabulary.maximumRecognitionHints)
    }

    private static func checkDomainVocabularyRewritesConfiguredPhrases() {
        let vocabulary = DomainVocabulary(terms: [
            DomainVocabulary.Term(text: "traderops", replacements: ["trade the rocks"]),
            DomainVocabulary.Term(text: "CLI", replacements: ["lie", "see el eye"]),
        ])

        expect(vocabulary.rewrite("ship trade the rocks.") == "ship traderops.")
        expect(vocabulary.rewrite("open see el eye") == "open CLI")
        expect(vocabulary.rewrite("open the lie") == "open the CLI")
        expect(vocabulary.rewrite("pretrade the rocks should stay") == "pretrade the rocks should stay")
    }

    private static func checkDomainVocabularyUsesReplaceJSONKey() {
        let data = """
        {
          "terms": [
            {
              "text": "CLI",
              "hints": ["C L I"],
              "replace": ["see el eye"]
            }
          ]
        }
        """.data(using: .utf8)!

        let vocabulary = try! JSONDecoder().decode(DomainVocabulary.self, from: data)
        let encoded = String(data: try! JSONEncoder().encode(vocabulary), encoding: .utf8)!

        expect(vocabulary.terms.first?.replacements == ["see el eye"])
        expect(encoded.contains("\"replace\""))
    }

    private static func checkSayTypeStatesExposeHumanStatusText() {
        expect(SayTypeState.idle.statusText == "Ready")
        expect(SayTypeState.hotkeyReceived.isBusy)
        expect(SayTypeState.recording(partialText: "").statusText == "Recording")
        expect(SayTypeState.recording(partialText: "hello").statusText == "Recording: hello")
        expect(!SayTypeState.finished(text: "done").isBusy)
    }

    private static func checkHotKeyToggleStartsFromIdleWithFeedback() {
        expect(SayTypeState.idle.toggleAction(fromHotKey: true) == .showHotKeyThenStart)
    }

    private static func checkHotKeyToggleStopsWhileRecording() {
        expect(SayTypeState.recording(partialText: "hello").toggleAction(fromHotKey: true) == .stop)
    }

    private static func checkMenuToggleStartsWithoutHotKeyFeedback() {
        expect(SayTypeState.idle.toggleAction(fromHotKey: false) == .start)
    }

    private static func checkBusyToggleStatesIgnoreRepeatedToggle() {
        expect(SayTypeState.hotkeyReceived.toggleAction(fromHotKey: true) == .ignore)
        expect(SayTypeState.preparing.toggleAction(fromHotKey: true) == .ignore)
        expect(SayTypeState.transcribing(partialText: "").toggleAction(fromHotKey: true) == .ignore)
        expect(SayTypeState.pasting(text: "hello").toggleAction(fromHotKey: true) == .ignore)
    }

    private static func checkDefaultHotKeyUsesOptionSpace() {
        expect(SayTypeDefaults.hotKey.displayName == "Option+Space")
        expect(SayTypeDefaults.hotKey.carbonKeyCode == 49)
        expect(SayTypeDefaults.hotKey.carbonModifiers == 0x0800)
    }

    private static func checkAudioInputSelectorPrefersBuiltInMicOverDefaultBluetooth() {
        let selected = AudioInputSelector.preferredInput(from: [
            AudioInputCandidate(
                id: 10,
                name: "Matthew's AirPods",
                inputChannelCount: 1,
                transport: .bluetooth,
                isDefault: true
            ),
            AudioInputCandidate(
                id: 20,
                name: "MacBook Air Microphone",
                inputChannelCount: 1,
                transport: .builtIn
            ),
        ])

        expect(selected?.name == "MacBook Air Microphone")
    }

    private static func checkAudioInputSelectorFallsBackToDefaultPhysicalInput() {
        let selected = AudioInputSelector.preferredInput(from: [
            AudioInputCandidate(id: 10, name: "USB Microphone", inputChannelCount: 1, transport: .usb, isDefault: true),
            AudioInputCandidate(id: 20, name: "Conference Headset", inputChannelCount: 1, transport: .bluetooth),
        ])

        expect(selected?.name == "USB Microphone")
    }

    private static func checkAudioInputSelectorIgnoresOutputOnlyDevices() {
        let selected = AudioInputSelector.preferredInput(from: [
            AudioInputCandidate(id: 10, name: "MacBook Air Speakers", inputChannelCount: 0, transport: .builtIn),
            AudioInputCandidate(id: 20, name: "Desk Mic", inputChannelCount: 1, transport: .usb),
        ])

        expect(selected?.name == "Desk Mic")
    }

    private static func checkAudioInputSelectorUsesVirtualOnlyAsLastResort() {
        let selected = AudioInputSelector.preferredInput(from: [
            AudioInputCandidate(id: 10, name: "Jump Desktop Microphone", inputChannelCount: 8, transport: .virtual),
        ])

        expect(selected?.name == "Jump Desktop Microphone")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, file: StaticString = #file, line: UInt = #line) {
        guard condition() else {
            fputs("Check failed at \(file):\(line)\n", stderr)
            exit(1)
        }
    }
}
