import Foundation

public struct SavedChat: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let preview: String
    public let updatedAt: Date
    public let isPinned: Bool

    public init(id: String, title: String, preview: String, updatedAt: Date, isPinned: Bool = false) {
        self.id = id
        self.title = title
        self.preview = preview
        self.updatedAt = updatedAt
        self.isPinned = isPinned
    }

    func pinned(_ value: Bool) -> SavedChat {
        SavedChat(id: id, title: title, preview: preview, updatedAt: updatedAt, isPinned: value)
    }
}
