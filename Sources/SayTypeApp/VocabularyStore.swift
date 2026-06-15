import Foundation
import SayTypeCore

enum VocabularyStore {
    static func load() -> DomainVocabulary {
        do {
            let url = try vocabularyURL()
            if FileManager.default.fileExists(atPath: url.path) {
                let data = try Data(contentsOf: url)
                let vocabulary = try JSONDecoder().decode(DomainVocabulary.self, from: data)
                AppLog.write("loaded domain vocabulary terms=\(vocabulary.terms.count) path=\(url.path)")
                return vocabulary
            }

            let vocabulary = DomainVocabulary.builtIn
            try write(vocabulary, to: url)
            AppLog.write("created domain vocabulary terms=\(vocabulary.terms.count) path=\(url.path)")
            return vocabulary
        } catch {
            AppLog.write("domain vocabulary fallback: \(error.localizedDescription)")
            return .builtIn
        }
    }

    static func vocabularyURL() throws -> URL {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }

        return applicationSupport
            .appendingPathComponent("SayType", isDirectory: true)
            .appendingPathComponent("dictionary.json", isDirectory: false)
    }

    private static func write(_ vocabulary: DomainVocabulary, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        let data = try encoder.encode(vocabulary)
        try data.write(to: url, options: .atomic)
    }
}
