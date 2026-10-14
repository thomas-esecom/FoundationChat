import Foundation

public protocol ChatTrash: Sendable {
    func moveToTrash(_ url: URL) throws
}

public struct SystemChatTrash: ChatTrash {
    public init() {}

    public func moveToTrash(_ url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}

public struct SavedChatDeletion: Sendable {
    public let deletedIDs: Set<String>
    public let warnings: [String]
}
