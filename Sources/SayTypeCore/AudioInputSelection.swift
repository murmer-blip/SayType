import Foundation

public enum AudioInputTransport: String, Equatable, Sendable {
    case builtIn
    case bluetooth
    case usb
    case virtual
    case other
    case unknown
}

public struct AudioInputCandidate: Equatable, Sendable {
    public let id: UInt32
    public let name: String
    public let manufacturer: String
    public let inputChannelCount: UInt32
    public let transport: AudioInputTransport
    public let isDefault: Bool

    public init(
        id: UInt32,
        name: String,
        manufacturer: String = "",
        inputChannelCount: UInt32,
        transport: AudioInputTransport,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.inputChannelCount = inputChannelCount
        self.transport = transport
        self.isDefault = isDefault
    }
}

public enum AudioInputSelector {
    public static func preferredInput(from candidates: [AudioInputCandidate]) -> AudioInputCandidate? {
        candidates
            .filter { $0.inputChannelCount > 0 }
            .min { lhs, rhs in
                let lhsScore = score(lhs)
                let rhsScore = score(rhs)
                if lhsScore != rhsScore {
                    return lhsScore < rhsScore
                }
                return lhs.id < rhs.id
            }
    }

    private static func score(_ candidate: AudioInputCandidate) -> Int {
        switch candidate.transport {
        case .builtIn:
            return candidate.name.lowercased().contains("mic") ? 0 : 1
        case .usb, .other, .unknown:
            return candidate.isDefault ? 2 : 3
        case .bluetooth:
            return candidate.isDefault ? 4 : 5
        case .virtual:
            return candidate.isDefault ? 6 : 7
        }
    }
}
