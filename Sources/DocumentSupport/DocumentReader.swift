import Foundation
import PDFKit

public actor DocumentReader {
    public static let textExtensions = ["txt", "md", "markdown", "csv", "tsv", "json", "xml", "html", "log", "swift", "php", "js", "css", "sql", "yaml", "yml"]
    private let maximumFileBytes = 10 * 1024 * 1024
    private let maximumTextBytes = 48 * 1024

    public init() {}

    public func read(_ url: URL) throws -> ChatDocument {
        let kind = url.pathExtension.lowercased()
        guard kind == "pdf" || Self.textExtensions.contains(kind) else { throw DocumentReadError.unsupportedFormat }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumFileBytes + 1) ?? Data()
        guard data.count <= maximumFileBytes else { throw DocumentReadError.fileTooLarge }

        let text: String
        if kind == "pdf" {
            guard let pdf = PDFDocument(data: data) else { throw DocumentReadError.invalidPDF }
            guard !pdf.isLocked else { throw DocumentReadError.lockedPDF }
            var pages: [String] = []
            var byteCount = 0
            for index in 0..<pdf.pageCount {
                let pageText = pdf.page(at: index)?.string ?? ""
                byteCount += pageText.utf8.count + 2
                guard byteCount <= maximumTextBytes else { throw DocumentReadError.textTooLarge }
                pages.append(pageText)
            }
            text = pages.joined(separator: "\n\n")
        } else {
            guard let decoded = String(data: data, encoding: .utf8) else { throw DocumentReadError.invalidUTF8 }
            text = decoded
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DocumentReadError.noText }
        guard text.utf8.count <= maximumTextBytes else { throw DocumentReadError.textTooLarge }
        return ChatDocument(name: url.lastPathComponent, text: text)
    }
}
