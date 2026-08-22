public struct PopupStackID: Sendable, Hashable, RawRepresentable {
    public let rawValue: String

    public static let shared = Self("shared")

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}
