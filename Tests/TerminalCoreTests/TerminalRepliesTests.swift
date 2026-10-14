import Foundation
import Testing
@testable import TerminalCore

struct TerminalRepliesTests {
    @Test func separatesAnswersFromQuestionsAndDocumentContents() {
        let lines = [line("Header"), line(" > Frage", prompt: true), line("   Dokumentinhalt", prompt: true), line(""),
            line("Antwort 👋"), line("    if True:"), line("        print(1)"), line(""), line(" > Zweite Frage", prompt: true), line("Zweite Antwort")]
        let replies = TerminalReplies.extract(from: lines, lastReplyComplete: true)
        #expect(replies.count == 2)
        #expect(replies[0].text == "Antwort 👋\n    if True:\n        print(1)")
        #expect(replies[1].text == "Zweite Antwort")
        let text = lines.map { $0.map(\.text).joined() }.joined(separator: "\n") as NSString
        #expect(text.substring(with: replies[0].range) == replies[0].text)
    }

    @Test func doesNotOfferThinkingOrIncompleteLastAnswerForCopying() {
        let lines = [line(" > Frage eins", prompt: true), line("Antwort eins"), line(" > Frage zwei", prompt: true), line("Thinking…")]
        let replies = TerminalReplies.extract(from: lines, lastReplyComplete: false)
        #expect(replies.map(\.text) == ["Antwort eins"])
    }

    @Test func quotedTextInsideAnswerDoesNotStartAnotherChatTurn() {
        let lines = [line(" > Frage", prompt: true), line("Antwort"), line("> Ein Zitat"), line("Weiterer Text")]
        let replies = TerminalReplies.extract(from: lines, lastReplyComplete: true)
        #expect(replies.count == 1)
        #expect(replies[0].text == "Antwort\n> Ein Zitat\nWeiterer Text")
    }

    @Test func recordedFMAnswerCopiesCodeWithoutPromptOrStatus() throws {
        let url = try #require(Bundle.module.url(forResource: "fm-code-response", withExtension: "bin", subdirectory: "Fixtures"))
        var screen = TerminalScreen(columns: 100, rows: 30)
        screen.append(try Data(contentsOf: url))
        let replies = TerminalReplies.extract(from: screen.displayLines, lastReplyComplete: screen.isReady)
        #expect(replies.count == 1)
        let reply = try #require(replies.first)
        #expect(reply.text.contains("print(\"Hallo\")"))
        #expect(reply.text.contains("Schreibe nur") == false)
        #expect(reply.text.contains("turn 1") == false)
    }

    private func line(_ text: String, prompt: Bool = false) -> [TerminalCell] {
        var style = TerminalStyle()
        if prompt { style.foreground = 0x999999; style.background = 0x26262A }
        return text.unicodeScalars.map { TerminalCell(text: String($0), style: style) }
    }
}
