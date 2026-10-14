import DocumentSupport
import Foundation

struct TemporaryChatImage {
    let directory: URL
    let url: URL

    init(_ document: ChatDocument, root: URL = FileManager.default.temporaryDirectory) throws {
        guard let data = document.imageData, let kind = document.imageExtension, ["jpg", "png"].contains(kind) else {
            throw DocumentReadError.invalidImage
        }
        directory = root.appending(path: "FoundationChat-image-\(UUID())", directoryHint: .isDirectory)
        url = directory.appending(path: "Bild.\(kind)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700])
        do {
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        } catch {
            remove()
            throw error
        }
    }

    func remove() {
        do { try FileManager.default.removeItem(at: directory) }
        catch { NSLog("Temporärer Bildanhang konnte nicht entfernt werden: %@", error.localizedDescription) }
    }
}
