import Foundation

public struct TerminalReply: Identifiable, Equatable, Sendable {
    public let id: Int
    public let range: NSRange
    public let text: String

    public init(id: Int, range: NSRange, text: String) {
        self.id = id
        self.range = range
        self.text = text
    }
}
