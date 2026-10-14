public struct TerminalCell: Equatable, Sendable {
    public var text: String
    public var style: TerminalStyle

    public init(text: String = " ", style: TerminalStyle = TerminalStyle()) {
        self.text = text
        self.style = style
    }
}
