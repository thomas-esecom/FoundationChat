import CoreGraphics
import CoreText
import DocumentSupport
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

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

    @Test(arguments: ["PNG", "JPG", "jpeg"])
    func readsImagesWithoutConvertingThemToText(_ kind: String) async throws {
        let data = try imageData(kind.lowercased() == "png" ? .png : .jpeg)
        let url = try temporaryFile(name: "Foto mit Leerzeichen.\(kind)", data: data)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let image = try await DocumentReader().read(url)
        #expect(image.isImage)
        #expect(image.imageData == data)
        #expect(image.text.isEmpty)
        #expect(image.name == url.lastPathComponent)
        #expect(image.imageExtension == (kind.lowercased() == "png" ? "png" : "jpg"))
        #expect(image.prompt(with: "Beschreibe dieses Bild") == "Beschreibe dieses Bild")
    }

    @Test func rejectsTextRenamedToJPG() async throws {
        let url = try temporaryFile(name: "Fake.jpg", data: Data("Ich bin kein Bild".utf8))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        await #expect(throws: DocumentReadError.invalidImage) { try await DocumentReader().read(url) }
    }

    @Test func rejectsOtherImageFormatsRenamedToPNG() async throws {
        let url = try temporaryFile(name: "Fake.png", data: imageData(.tiff))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        await #expect(throws: DocumentReadError.invalidImage) { try await DocumentReader().read(url) }
    }

    @Test func rejectsOversizedImageBeforeDecoding() async throws {
        let url = try temporaryFile(name: "Gross.jpg", data: Data(repeating: 0, count: 10 * 1024 * 1024 + 1))
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        await #expect(throws: DocumentReadError.fileTooLarge) { try await DocumentReader().read(url) }
    }

    private func imageData(_ type: UTType) throws -> Data {
        let context = try #require(CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8,
            bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0, green: 0.7, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func temporaryFile(name: String, data: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: "FoundationChatTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: name)
        try data.write(to: url)
        return url
    }
}
