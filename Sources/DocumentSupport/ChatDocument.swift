import Foundation

public struct ChatDocument: Sendable {
    public let name: String
    public let text: String

    public init(name: String, text: String) {
        self.name = name
        self.text = text
    }

    public func prompt(with message: String) -> String {
        "\(message)\n\nDokument: \(name)\n--- Dokumentanfang ---\n\(text)\n--- Dokumentende ---"
    }
}
