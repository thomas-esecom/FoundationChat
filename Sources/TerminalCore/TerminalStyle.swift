public struct TerminalStyle: Equatable, Sendable {
    public var foreground: UInt32?
    public var background: UInt32?
    public var bold = false
    public var dim = false
    public var italic = false
    public var underline = false
    public var inverse = false

    public init() {}
}
