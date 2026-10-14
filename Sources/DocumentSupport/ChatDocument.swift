import Foundation

public struct ChatDocument: Sendable {
    public let name: String
    public let text: String
    public let imageData: Data?
    public let imageExtension: String?
    public var isImage: Bool { imageData != nil }

    public init(name: String, text: String) {
        self.name = name
        self.text = text
        self.imageData = nil
        self.imageExtension = nil
    }

    public init(name: String, imageData: Data, imageExtension: String) {
        self.name = name
        self.text = ""
        self.imageData = imageData
        self.imageExtension = imageExtension
    }

    public func prompt(with message: String) -> String {
        if isImage { return message }
        return "\(message)\n\nDokument: \(name)\n--- Dokumentanfang ---\n\(text)\n--- Dokumentende ---"
    }
}
