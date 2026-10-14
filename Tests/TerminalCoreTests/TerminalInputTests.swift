import Foundation
import TerminalCore
import Testing

struct TerminalInputTests {
    @Test func pastesImageSeparatelyBeforeMultilineQuestionAndSubmitsOnce() throws {
        let data = try #require(TerminalInput.encode("Welche Farbe?\nUnd welche Form?", imagePath: "/tmp/Bild.png", bracketedPaste: true))
        let input = String(decoding: data, as: UTF8.self)
        #expect(input == "\u{15}\u{1B}[200~/tmp/Bild.png\u{1B}[201~ \u{1B}[200~Welche Farbe?\nUnd welche Form?\u{1B}[201~\r")
        #expect(input.filter { $0 == "\r" }.count == 1)
    }

    @Test func refusesToSendAnImageAsAPlainFilePath() {
        #expect(TerminalInput.encode("Beschreibe das Bild", imagePath: "/tmp/Bild.jpg", bracketedPaste: false) == nil)
    }

    @Test func preservesTextOnlyInputAndNormalizesLineEndings() throws {
        let bracketed = try #require(TerminalInput.encode("Erste\r\nZweite\rDritte", bracketedPaste: true))
        #expect(String(decoding: bracketed, as: UTF8.self) == "\u{15}\u{1B}[200~Erste\nZweite\nDritte\u{1B}[201~\r")
        let plain = try #require(TerminalInput.encode("Erste\nZweite", bracketedPaste: false))
        #expect(String(decoding: plain, as: UTF8.self) == "Erste Zweite\n")
    }
}
