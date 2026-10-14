import ChatHistory
import Foundation
import Testing

struct SavedChatStoreTests {
    @Test func readsRealFMSchemaAndOrdersByModificationTime() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeChat("older", prompt: "Erste Frage\n\nDokument: Privat.txt", reply: "Ältere Antwort", date: 100, directory: directory)
        try writeChat("newer", prompt: "Zweite Frage", reply: "Neue\nAntwort", date: 200, directory: directory)
        let result = try await SavedChatStore(directory: directory).read()
        #expect(result.chats.map(\.id) == ["newer", "older"])
        #expect(result.chats[1].title == "Erste Frage")
        #expect(result.chats[0].preview == "Neue Antwort")
        #expect(result.warnings.isEmpty)
    }

    @Test func reportsInvalidSessionWithoutHidingValidChats() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try writeChat("valid", prompt: "Frage", reply: "Antwort", date: 100, directory: directory)
        try Data("not JSON".utf8).write(to: directory.appending(path: "broken.json"))
        let result = try await SavedChatStore(directory: directory).read()
        #expect(result.chats.map(\.id) == ["valid"])
        #expect(result.warnings.count == 1)
        #expect(result.warnings[0].contains("broken.json"))
    }

    @Test func missingDirectoryIsAnEmptyHistory() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "MissingChats-\(UUID())")
        let result = try await SavedChatStore(directory: directory).read()
        #expect(result.chats.isEmpty)
        #expect(result.warnings.isEmpty)
    }

    @Test func refreshUpdatesCachedChatAfterNewResponse() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SavedChatStore(directory: directory)
        try writeChat("saved", prompt: "Frage", reply: "Alte Antwort", date: 100, directory: directory)
        let first = try await store.read()
        #expect(first.chats.first?.preview == "Alte Antwort")
        try writeChat("saved", prompt: "Frage", reply: "Neue Antwort", date: 200, directory: directory)
        let updated = try await store.read()
        #expect(updated.chats.first?.preview == "Neue Antwort")
    }

    @Test func pinsPersistAndKeepBothGroupsInTimeOrder() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        for (name, date) in [("oldest", 100.0), ("middle", 200.0), ("newest", 300.0)] {
            try writeChat(name, prompt: name, reply: "Antwort", date: date, directory: directory)
        }
        let store = SavedChatStore(directory: directory)
        _ = try await store.read()
        try await store.setPinned(true, id: "oldest")
        try await store.setPinned(true, id: "middle")
        let cached = try await store.read()
        #expect(cached.chats.map(\.id) == ["middle", "oldest", "newest"])
        #expect(cached.chats.map(\.isPinned) == [true, true, false])
        let reopened = try await SavedChatStore(directory: directory).read()
        #expect(reopened.chats == cached.chats)
        try await store.setPinned(false, id: "middle")
        let unpinned = try await store.read()
        #expect(unpinned.chats.map(\.id) == ["oldest", "newest", "middle"])
        #expect(unpinned.chats[0].updatedAt == Date(timeIntervalSince1970: 100))
    }

    @Test func deletesOnlySelectedChatsAndPreservesRecoverableCopies() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let trashDirectory = directory.appending(path: "trash")
        try FileManager.default.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
        let store = SavedChatStore(directory: directory, trash: TestTrash(directory: trashDirectory))
        for name in ["first", "second", "keep"] {
            try writeChat(name, prompt: name, reply: "Antwort", date: 100, directory: directory)
        }
        try await store.setPinned(true, id: "first")
        _ = try await store.read()
        let result = try await store.delete(ids: ["first", "second"])
        #expect(result.deletedIDs == ["first", "second"])
        #expect(result.warnings.isEmpty)
        let remaining = try await store.read()
        #expect(remaining.chats.map(\.id) == ["keep"])
        #expect(FileManager.default.fileExists(atPath: trashDirectory.appending(path: "first.json").path))
        #expect(FileManager.default.fileExists(atPath: trashDirectory.appending(path: "second.json").path))
        // A restored file must not inherit a stale pin.
        try FileManager.default.moveItem(at: trashDirectory.appending(path: "first.json"), to: directory.appending(path: "first.json"))
        let restored = try await store.read()
        #expect(restored.chats.allSatisfy { !$0.isPinned })
    }

    @Test func partialDeletionReportsFailureAndKeepsFailedChatPinned() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let trashDirectory = directory.appending(path: "trash")
        try FileManager.default.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
        let store = SavedChatStore(directory: directory, trash: TestTrash(directory: trashDirectory, failingID: "keep"))
        for name in ["remove", "keep"] {
            try writeChat(name, prompt: name, reply: "Antwort", date: 100, directory: directory)
        }
        try await store.setPinned(true, id: "keep")
        let result = try await store.delete(ids: ["remove", "keep"])
        #expect(result.deletedIDs == ["remove"])
        #expect(result.warnings.count == 1)
        let remaining = try await store.read()
        #expect(remaining.chats.map(\.id) == ["keep"])
        #expect(remaining.chats[0].isPinned)
    }

    @Test func refusesUnsafeIDsAndDoesNotDeleteOtherFiles() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SavedChatStore(directory: directory, trash: TestTrash(directory: directory))
        try writeChat("keep", prompt: "Frage", reply: "Antwort", date: 100, directory: directory)
        for id in ["../keep", "", ".foundationchat-pins", "folder/keep", "folder\\keep"] {
            await #expect(throws: CocoaError.self) { try await store.setPinned(true, id: id) }
        }
        let result = try await store.delete(ids: ["../keep", ".foundationchat-pins"])
        #expect(result.deletedIDs.isEmpty)
        #expect(result.warnings.count == 2)
        #expect(FileManager.default.fileExists(atPath: directory.appending(path: "keep.json").path))
    }

    private struct TestTrash: ChatTrash {
        let directory: URL
        var failingID: String? = nil

        func moveToTrash(_ url: URL) throws {
            if url.deletingPathExtension().lastPathComponent == failingID { throw CocoaError(.fileWriteNoPermission) }
            try FileManager.default.moveItem(at: url, to: directory.appending(path: url.lastPathComponent))
        }
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ChatHistoryTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func writeChat(_ name: String, prompt: String, reply: String, date: TimeInterval, directory: URL) throws {
        let value: [String: Any] = ["modelName": "system", "transcript": ["type": "model", "version": "1", "transcript": ["entries": [
            ["role": "user", "contents": [["type": "text", "text": prompt]]],
            ["role": "response", "contents": [["type": "text", "text": reply]]],
        ]]]]
        let url = directory.appending(path: name + ".json")
        try JSONSerialization.data(withJSONObject: value).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: date)], ofItemAtPath: url.path)
    }
}
