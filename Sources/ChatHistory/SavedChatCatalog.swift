public struct SavedChatCatalog: Sendable {
    public let chats: [SavedChat]
    public let warnings: [String]

    public init(chats: [SavedChat], warnings: [String]) {
        self.chats = chats
        self.warnings = warnings
    }
}
