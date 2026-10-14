import Foundation

public enum TerminalInput {
    public static func encode(_ message: String, imagePath: String? = nil, bracketedPaste: Bool) -> Data? {
        guard imagePath == nil || bracketedPaste else { return nil }
        let normalized = message.replacing("\r\n", with: "\n").replacing("\r", with: "\n")
        if bracketedPaste {
            let image = imagePath.map { "\u{1B}[200~" + $0 + "\u{1B}[201~ " } ?? ""
            // Input lives in the app's composer. Clear stray terminal-probe text
            // from fm's hidden input line before pasting the actual message.
            return Data(("\u{15}" + image + "\u{1B}[200~" + normalized + "\u{1B}[201~\r").utf8)
        }
        return Data((normalized.replacing("\n", with: " ") + "\n").utf8)
    }
}
