import Foundation

public actor SavedChatStore {
    private let directory: URL
    private let trash: any ChatTrash
    private var pinsURL: URL { directory.appending(path: ".foundationchat-pins.json") }
    private var cache: [URL: (modified: Date, size: Int, chat: SavedChat)] = [:]

    public init(directory: URL, trash: any ChatTrash = SystemChatTrash()) {
        self.directory = directory
        self.trash = trash
    }

    public func read() throws -> SavedChatCatalog {
        guard FileManager.default.fileExists(atPath: directory.path) else {
            return SavedChatCatalog(chats: [], warnings: [])
        }
        let pinnedIDs = try readPins()
        let files = try FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey], options: .skipsHiddenFiles)
        var chats: [SavedChat] = []
        var warnings: [String] = []
        let existing = Set(files)
        cache = cache.filter { existing.contains($0.key) }
        for file in files where file.pathExtension.lowercased() == "json" {
            do {
                let metadata = try file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                let modified = metadata.contentModificationDate ?? .distantPast
                let size = metadata.fileSize ?? 0
                if let cached = cache[file], cached.modified == modified, cached.size == size {
                    chats.append(cached.chat.pinned(pinnedIDs.contains(cached.chat.id)))
                    continue
                }
                guard (metadata.fileSize ?? 0) <= 4 * 1024 * 1024 else {
                    warnings.append("\(file.lastPathComponent): Chatdatei größer als 4 MB.")
                    continue
                }
                let data = try Data(contentsOf: file)
                let session = try JSONDecoder().decode(SessionFile.self, from: data)
                let entries = session.transcript.transcript.entries
                let prompt = entries.first(where: { $0.role == "user" })?.text ?? ""
                let reply = entries.last(where: { $0.role == "response" })?.text ?? ""
                let name = file.deletingPathExtension().lastPathComponent
                let firstLine = prompt.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces) ?? ""
                let chat = SavedChat(id: name, title: firstLine.isEmpty ? name : String(firstLine.prefix(90)),
                    preview: String(reply.replacing("\n", with: " ").prefix(100)), updatedAt: modified)
                cache[file] = (modified, size, chat)
                chats.append(chat.pinned(pinnedIDs.contains(chat.id)))
            } catch {
                warnings.append("\(file.lastPathComponent): \(error.localizedDescription)")
            }
        }
        chats.sort {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt == $1.updatedAt ? $0.id < $1.id : $0.updatedAt > $1.updatedAt
        }
        return SavedChatCatalog(chats: chats, warnings: warnings)
    }

    public func setPinned(_ pinned: Bool, id: String) throws {
        let url = try sessionURL(id)
        guard FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile) }
        var ids = try readPins()
        if pinned { ids.insert(id) } else { ids.remove(id) }
        try writePins(ids)
    }

    public func delete(ids: Set<String>) throws -> SavedChatDeletion {
        var pinnedIDs = try readPins()
        var deletedIDs: Set<String> = []
        var warnings: [String] = []
        for id in ids.sorted() {
            do {
                let url = try sessionURL(id)
                try trash.moveToTrash(url)
                cache.removeValue(forKey: url)
                pinnedIDs.remove(id)
                deletedIDs.insert(id)
            } catch {
                warnings.append("\(id): \(error.localizedDescription)")
            }
        }
        if !deletedIDs.isEmpty {
            do { try writePins(pinnedIDs) }
            catch { warnings.append("Anheftungen konnten nicht aktualisiert werden: \(error.localizedDescription)") }
        }
        return SavedChatDeletion(deletedIDs: deletedIDs, warnings: warnings)
    }

    private func sessionURL(_ id: String) throws -> URL {
        guard !id.isEmpty, id != ".", id != "..", !id.contains("/"), !id.contains("\\"), !id.contains("\0"), !id.hasPrefix(".") else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        return directory.appending(path: id + ".json")
    }

    private func readPins() throws -> Set<String> {
        guard FileManager.default.fileExists(atPath: pinsURL.path) else { return [] }
        return Set(try JSONDecoder().decode([String].self, from: Data(contentsOf: pinsURL)))
    }

    private func writePins(_ ids: Set<String>) throws {
        try JSONEncoder().encode(ids.sorted()).write(to: pinsURL, options: .atomic)
    }

    private struct SessionFile: Decodable {
        let transcript: Wrapper
        struct Wrapper: Decodable {
            let transcript: Transcript
        }
        struct Transcript: Decodable {
            let entries: [Entry]
        }
        struct Entry: Decodable {
            let role: String
            let contents: [Content]
            var text: String { contents.compactMap(\.text).joined(separator: "\n") }
        }
        struct Content: Decodable { let text: String? }
    }
}
