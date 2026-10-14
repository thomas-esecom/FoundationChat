import CoreGraphics
import CoreText
import DocumentSupport
import Foundation
import Testing

struct DocumentReaderTests {
    @Test func readsUTF8AndPreservesParagraphsInPrompt() async throws {
        let url = try temporaryFile(name: "Notiz.md", data: Data("Grüße 👋\n\nPrüfnummer: KI-4279".utf8))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let document = try await DocumentReader().read(url)
        #expect(document.name == "Notiz.md")
        #expect(document.text == "Grüße 👋\n\nPrüfnummer: KI-4279")
        #expect(document.prompt(with: "Nenne die Prüfnummer").contains("\n\nPrüfnummer: KI-4279\n--- Dokumentende ---"))
    }

    @Test func extractsActualPDFText() async throws {
        let bytes = NSMutableData()
        let consumer = try #require(CGDataConsumer(data: bytes))
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        context.beginPDFPage(nil)
        context.textPosition = CGPoint(x: 50, y: 780)
        let line = CTLineCreateWithAttributedString(NSAttributedString(
            string: "PDF-Pruefnummer: TEST-314",
            attributes: [NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Helvetica" as CFString, 12, nil)]
        ))
        CTLineDraw(line, context)
        context.endPDFPage()
        context.closePDF()
        let url = try temporaryFile(name: "Dokument.pdf", data: bytes as Data)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let document = try await DocumentReader().read(url)
        #expect(document.text.contains("TEST-314"))
    }

    @Test func rejectsInvalidUTF8WithoutReplacingOrDroppingBytes() async throws {
        let url = try temporaryFile(name: "Notiz.txt", data: Data([0xFF, 0xFE, 0xFF]))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        await #expect(throws: DocumentReadError.invalidUTF8) { try await DocumentReader().read(url) }
    }

    @Test func rejectsLongTextWithoutTruncation() async throws {
        let url = try temporaryFile(name: "Notiz.txt", data: Data(repeating: 65, count: 49 * 1024))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        await #expect(throws: DocumentReadError.textTooLarge) { try await DocumentReader().read(url) }
    }

    @Test func rejectsUnsupportedWordFileExplicitly() async throws {
        let url = try temporaryFile(name: "Dokument.docx", data: Data())
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        await #expect(throws: DocumentReadError.unsupportedFormat) { try await DocumentReader().read(url) }
    }

    @Test func rejectsEmptyDocument() async throws {
        let url = try temporaryFile(name: "Notiz.txt", data: Data(" \n ".utf8))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        await #expect(throws: DocumentReadError.noText) { try await DocumentReader().read(url) }
    }

    private func temporaryFile(name: String, data: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "FoundationChatTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: name)
        try data.write(to: url)
        return url
    }
}
