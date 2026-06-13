import Foundation

public struct TranscriptAssembler: Equatable, Sendable {
    private var finalizedSegments: [String] = []
    private var volatileText = ""

    public init() {}

    public var text: String {
        normalize(([finalizedSegments.joined(separator: " "), volatileText])
            .filter { !$0.isEmpty }
            .joined(separator: " "))
    }

    public mutating func accept(text rawText: String, isFinal: Bool) {
        let cleaned = normalize(rawText)
        guard !cleaned.isEmpty else { return }
        if isFinal {
            finalizedSegments.append(cleaned)
            volatileText = ""
        } else {
            volatileText = cleaned
        }
    }

    public mutating func reset() {
        finalizedSegments.removeAll()
        volatileText = ""
    }
}

public func normalize(_ text: String) -> String {
    text
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
}
