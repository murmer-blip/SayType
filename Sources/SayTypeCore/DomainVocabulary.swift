import Foundation

public struct DomainVocabulary: Codable, Equatable, Sendable {
    public struct Term: Codable, Equatable, Sendable {
        public var text: String
        public var hints: [String]
        public var replacements: [String]

        public init(text: String, hints: [String] = [], replacements: [String] = []) {
            self.text = text
            self.hints = hints
            self.replacements = replacements
        }

        private enum CodingKeys: String, CodingKey {
            case text
            case hints
            case replacements = "replace"
        }
    }

    public static let maximumRecognitionHints = 100

    public static let builtIn = DomainVocabulary(terms: [
        Term(
            text: "traderops",
            hints: ["traderops", "trader ops"],
            replacements: ["trade the rocks", "trade rocks", "trader ops"]
        ),
        Term(
            text: "CLI",
            hints: ["CLI", "C L I", "command line interface"],
            replacements: ["lie", "see el eye", "sea ell eye", "C L I"]
        ),
    ])

    public var terms: [Term]

    public init(terms: [Term] = []) {
        self.terms = terms
    }

    public var recognitionHints: [String] {
        var hints: [String] = []
        var seen: Set<String> = []

        for term in terms {
            appendUniqueHint(term.text, to: &hints, seen: &seen)
            for hint in term.hints {
                appendUniqueHint(hint, to: &hints, seen: &seen)
            }
        }

        return Array(hints.prefix(Self.maximumRecognitionHints))
    }

    public func rewrite(_ text: String) -> String {
        var rewritten = normalize(text)
        for term in terms {
            for phrase in term.replacements.sorted(by: shouldPreferForReplacement) {
                rewritten = replace(phrase: phrase, with: term.text, in: rewritten)
            }
        }
        return normalize(rewritten)
    }

    private func appendUniqueHint(_ hint: String, to hints: inout [String], seen: inout Set<String>) {
        let cleaned = normalize(hint)
        guard !cleaned.isEmpty else { return }

        let key = cleaned.lowercased()
        guard seen.insert(key).inserted else { return }

        hints.append(cleaned)
    }

    private func shouldPreferForReplacement(_ lhs: String, _ rhs: String) -> Bool {
        let left = normalize(lhs)
        let right = normalize(rhs)
        if left.count == right.count {
            return left < right
        }
        return left.count > right.count
    }

    private func replace(phrase: String, with replacement: String, in text: String) -> String {
        let tokens = normalize(phrase).split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return text }

        let body = tokens
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: #"\s+"#)
        let pattern = #"(?i)(?<![\p{L}\p{N}_])"# + body + #"(?![\p{L}\p{N}_])"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: NSRegularExpression.escapedTemplate(for: replacement)
        )
    }
}
