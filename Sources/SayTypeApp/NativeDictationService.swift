@preconcurrency import AVFoundation
import Foundation
import SayTypeCore
import Speech

enum DictationError: LocalizedError {
    case speechUnavailable
    case assetUnavailable
    case missingInputFormat
    case couldNotCreateBuffer

    var errorDescription: String? {
        switch self {
        case .speechUnavailable:
            "Apple on-device dictation is unavailable for this locale."
        case .assetUnavailable:
            "Apple dictation assets are not available on this Mac."
        case .missingInputFormat:
            "Could not find a microphone format for Apple dictation."
        case .couldNotCreateBuffer:
            "Could not prepare microphone audio for Apple dictation."
        }
    }
}

@MainActor
final class NativeDictationService {
    private var engine: AVAudioEngine?
    private var analyzer: SpeechAnalyzer?
    private var transcriber: DictationTranscriber?
    private var continuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analysisTask: Task<Void, Error>?
    private var resultsTask: Task<Void, Never>?
    private var assembler = TranscriptAssembler()
    private var partialHandler: ((String) -> Void)?

    var currentText: String {
        assembler.text
    }

    func start(partial: @escaping (String) -> Void) async throws {
        await cancel()
        partialHandler = partial
        assembler.reset()

        let locale = await preferredLocale()
        let transcriber = DictationTranscriber(locale: locale, preset: .progressiveLongDictation)
        let modules: [any SpeechModule] = [transcriber]
        try await ensureAssets(for: modules)

        let engine = AVAudioEngine()
        let selectedInput = try CoreAudioInputDevice.applyPreferredInput(to: engine)
        AppLog.write("selected input \(selectedInput.name) transport=\(selectedInput.transport.rawValue)")

        let input = engine.inputNode
        let naturalFormat = input.inputFormat(forBus: 0)
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: modules,
            considering: naturalFormat
        ) else {
            throw DictationError.missingInputFormat
        }

        let analyzer = SpeechAnalyzer(
            modules: modules,
            options: SpeechAnalyzer.Options(priority: .userInitiated, modelRetention: .processLifetime)
        )
        try await analyzer.prepareToAnalyze(in: analyzerFormat)

        let analyzerInput = AnalyzerInputStream.make(bufferingNewest: 32)
        continuation = analyzerInput.continuation
        let converter = PCMBufferConverter(inputFormat: naturalFormat, outputFormat: analyzerFormat)

        resultsTask = Task { @MainActor [weak self, transcriber] in
            do {
                for try await result in transcriber.results {
                    self?.assembler.accept(text: String(result.text.characters), isFinal: result.isFinal)
                    self?.partialHandler?(self?.assembler.text ?? "")
                }
            } catch {
                self?.partialHandler?(self?.assembler.text ?? "")
            }
        }

        analysisTask = Task {
            try await analyzer.start(inputSequence: analyzerInput.stream)
        }

        installAnalyzerTap(
            on: input,
            format: naturalFormat,
            sink: AnalyzerInputSink(converter: converter, continuation: analyzerInput.continuation)
        )

        try engine.start()
        self.engine = engine
        self.analyzer = analyzer
        self.transcriber = transcriber
    }

    func stop() async throws -> String {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        continuation?.finish()

        try await analyzer?.finalizeAndFinishThroughEndOfInput()
        try await analysisTask?.value
        resultsTask?.cancel()

        let text = assembler.text
        clearSession()
        return text
    }

    func cancel() async {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        continuation?.finish()
        await analyzer?.cancelAndFinishNow()
        analysisTask?.cancel()
        resultsTask?.cancel()
        clearSession()
    }

    private func clearSession() {
        engine = nil
        analyzer = nil
        transcriber = nil
        continuation = nil
        analysisTask = nil
        resultsTask = nil
        partialHandler = nil
    }

    private func preferredLocale() async -> Locale {
        let requested = Locale.current
        if let supported = await DictationTranscriber.supportedLocale(equivalentTo: requested) {
            return supported
        }
        if let english = await DictationTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en_US")) {
            return english
        }
        return requested
    }

    private func ensureAssets(for modules: [any SpeechModule]) async throws {
        switch await AssetInventory.status(forModules: modules) {
        case .installed:
            return
        case .supported, .downloading:
            guard let request = try await AssetInventory.assetInstallationRequest(supporting: modules) else {
                return
            }
            try await request.downloadAndInstall()
        case .unsupported:
            throw DictationError.assetUnavailable
        @unknown default:
            throw DictationError.assetUnavailable
        }
    }
}

private struct AnalyzerInputStream {
    let stream: AsyncStream<AnalyzerInput>
    let continuation: AsyncStream<AnalyzerInput>.Continuation

    static func make(bufferingNewest count: Int) -> AnalyzerInputStream {
        var capturedContinuation: AsyncStream<AnalyzerInput>.Continuation?
        let stream = AsyncStream<AnalyzerInput>(bufferingPolicy: .bufferingNewest(count)) { continuation in
            capturedContinuation = continuation
        }
        guard let capturedContinuation else {
            fatalError("AsyncStream did not provide a continuation")
        }
        return AnalyzerInputStream(stream: stream, continuation: capturedContinuation)
    }
}

private func installAnalyzerTap(
    on input: AVAudioInputNode,
    format: AVAudioFormat,
    sink: AnalyzerInputSink
) {
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
        sink.receive(buffer)
    }
}

private final class AnalyzerInputSink: @unchecked Sendable {
    private let converter: PCMBufferConverter
    private let continuation: AsyncStream<AnalyzerInput>.Continuation

    init(converter: PCMBufferConverter, continuation: AsyncStream<AnalyzerInput>.Continuation) {
        self.converter = converter
        self.continuation = continuation
    }

    func receive(_ buffer: AVAudioPCMBuffer) {
        guard let prepared = converter.convert(buffer) else {
            return
        }
        continuation.yield(AnalyzerInput(buffer: prepared))
    }
}

private final class PCMBufferConverter: @unchecked Sendable {
    private let inputFormat: AVAudioFormat
    private let outputFormat: AVAudioFormat
    private let converter: AVAudioConverter?

    init(inputFormat: AVAudioFormat, outputFormat: AVAudioFormat) {
        self.inputFormat = inputFormat
        self.outputFormat = outputFormat
        converter = inputFormat.isSayTypeEquivalent(to: outputFormat) ? nil : AVAudioConverter(from: inputFormat, to: outputFormat)
    }

    func convert(_ input: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let converter else {
            return input.sayTypeCopy()
        }

        let ratio = outputFormat.sampleRate / max(inputFormat.sampleRate, 1)
        let capacity = AVAudioFrameCount(Double(input.frameLength) * ratio) + 256
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            return nil
        }

        let inputProvider = OneShotInputProvider(input)
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, outStatus in
            inputProvider.next(outStatus)
        }

        switch status {
        case .haveData, .inputRanDry, .endOfStream:
            return output.frameLength > 0 ? output : nil
        case .error:
            return nil
        @unknown default:
            return nil
        }
    }
}

private final class OneShotInputProvider: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer: AVAudioPCMBuffer?

    init(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func next(_ outStatus: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        lock.lock()
        defer { lock.unlock() }

        guard let buffer else {
            outStatus.pointee = .noDataNow
            return nil
        }

        self.buffer = nil
        outStatus.pointee = .haveData
        return buffer
    }
}

private extension AVAudioFormat {
    func isSayTypeEquivalent(to other: AVAudioFormat) -> Bool {
        sampleRate == other.sampleRate
            && channelCount == other.channelCount
            && commonFormat == other.commonFormat
            && isInterleaved == other.isInterleaved
    }
}

private extension AVAudioPCMBuffer {
    func sayTypeCopy() -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else {
            return nil
        }
        copy.frameLength = frameLength

        let source = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: audioBufferList))
        let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for index in 0..<source.count {
            let sourceBuffer = source[index]
            var destinationBuffer = destination[index]
            guard let sourceData = sourceBuffer.mData, let destinationData = destinationBuffer.mData else {
                continue
            }
            memcpy(destinationData, sourceData, Int(sourceBuffer.mDataByteSize))
            destinationBuffer.mDataByteSize = sourceBuffer.mDataByteSize
            destination[index] = destinationBuffer
        }
        return copy
    }
}
