import Foundation

public struct HotKeySpec: Equatable, Sendable {
    public let displayName: String
    public let carbonKeyCode: UInt32
    public let carbonModifiers: UInt32

    public init(displayName: String, carbonKeyCode: UInt32, carbonModifiers: UInt32) {
        self.displayName = displayName
        self.carbonKeyCode = carbonKeyCode
        self.carbonModifiers = carbonModifiers
    }
}

public enum SayTypeDefaults {
    public static let hotKey = HotKeySpec(
        displayName: "Option+Space",
        carbonKeyCode: 49,
        carbonModifiers: 0x0800
    )
}
