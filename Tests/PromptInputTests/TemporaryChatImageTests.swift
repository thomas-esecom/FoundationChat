@testable import AppleFoundationChat
import DocumentSupport
import Foundation
import Testing

struct TemporaryChatImageTests {
    @Test func keepsPrivateSnapshotReadableUntilCleanupWithoutTouchingOriginal() throws {
        let data = Data([1, 2, 3, 4])
        let document = ChatDocument(name: "Foto mit Leerzeichen.png", imageData: data, imageExtension: "png")
        let staged = try TemporaryChatImage(document)
        defer { if FileManager.default.fileExists(atPath: staged.directory.path) { staged.remove() } }
        #expect(try Data(contentsOf: staged.url) == data)
        #expect(staged.url.pathExtension == "png")
        let permissions = try FileManager.default.attributesOfItem(atPath: staged.url.path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)
        staged.remove()
        #expect(FileManager.default.fileExists(atPath: staged.directory.path) == false)
        #expect(document.imageData == data)
    }

    @Test func refusesUnsupportedStagingExtension() throws {
        let document = ChatDocument(name: "Bild.gif", imageData: Data(), imageExtension: "../other")
        #expect(throws: DocumentReadError.invalidImage) { try TemporaryChatImage(document) }
    }
}
