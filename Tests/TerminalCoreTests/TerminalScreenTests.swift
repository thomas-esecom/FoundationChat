import Foundation
import Testing
@testable import TerminalCore

struct TerminalScreenTests {
    @Test func keepsQuestionColorAndCodeStyleAcrossChunks() {
        var terminal = TerminalScreen()
        for part in ["\u{1B}[38;2;153;", "153;153m> Frage\u{1B}[0m\r\nAntwort\r\n\u{1B}[2mprint(1)\u{1B}[0m"] {
            terminal.append(Data(part.utf8))
        }
        #expect(terminal.text == "> Frage\nAntwort\nprint(1)")
        #expect(terminal.displayLines[0][0].style.foreground == 0x999999)
        #expect(terminal.displayLines[1][0].style.foreground == nil)
        #expect(terminal.displayLines[2][0].style.dim == true)
    }

    @Test func separatesInputPaneAndRealTokenStatusFromTranscript() {
        var terminal = TerminalScreen()
        terminal.append(Data("Antwort\r\n╭──╮\r\n│ > │\r\n╰──╯\r\nsystem · turn 2 · ↑ 366 · ↓ 486 · 852 / 8.192 (10% used)".utf8))
        #expect(terminal.text == "Antwort")
        #expect(terminal.isReady == true)
        #expect(terminal.statusText == "system · turn 2 · ↑ 366 · ↓ 486 · 852 / 8.192 (10% used)")
        terminal.append(Data("\u{1B}[5;1H\u{1B}[Ksystem · turn 3 · ↑ 400 · ↓ 500 · 900 / 8.192 (11% used)".utf8))
        #expect(terminal.statusText.contains("turn 3"))
        #expect(terminal.text.contains("turn") == false)
    }

    @Test func unicodeSplitAtEveryByteAndWideEmojiKeepCursorPositions() {
        var terminal = TerminalScreen()
        for byte in Data("Grüße 👋!\u{1B}[1;9HX".utf8) { terminal.append(Data([byte])) }
        #expect(terminal.text == "Grüße 👋X")
    }

    @Test func scrollingPreservesHistoryAndSupportsAbsoluteScreenCoordinates() {
        var terminal = TerminalScreen(columns: 20, rows: 6)
        terminal.append(Data("1\r\n2\r\n3\r\n4\r\n5\r\n6\r\n7\u{1B}[1;1HX".utf8))
        #expect(terminal.text == "1\nX\n3\n4\n5\n6\n7")
    }

    @Test func repliesToAppearanceAndCursorQueriesWithoutRenderingThem() {
        var terminal = TerminalScreen()
        terminal.append(Data("\u{1B}]11;?\u{7}\u{1B}[3;4H\u{1B}[6n".utf8))
        #expect(String(decoding: terminal.takeReplies(), as: UTF8.self) == "\u{1B}]11;rgb:2020/2020/2020\u{1B}\\\u{1B}[3;4R")
        #expect(terminal.text.isEmpty)
        #expect(terminal.takeReplies().isEmpty)
    }

    @Test func resizeDoesNotDuplicateConversationOrRetainOldInputPane() {
        var terminal = TerminalScreen(columns: 80, rows: 20)
        let frame = "Antwort\r\n╭──╮\r\n│ > │\r\n╰──╯\r\nsystem · turn 1"
        terminal.append(Data(frame.utf8))
        terminal.resize(columns: 60, rows: 14)
        #expect(terminal.isReady == false)
        terminal.append(Data(("\u{1B}[14S\u{1B}[1;1H" + frame).utf8))
        #expect(terminal.text == "Antwort")
        #expect(terminal.isReady == true)
        #expect(terminal.statusText == "system · turn 1")
    }

    @Test(arguments: [1, 13, 4096])
    func recordedFMCodeResponseRendersWithColorsAndExactStatus(chunkSize: Int) throws {
        let url = try #require(Bundle.module.url(forResource: "fm-code-response", withExtension: "bin", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        var terminal = TerminalScreen(columns: 100, rows: 30)
        for offset in stride(from: 0, to: data.count, by: chunkSize) {
            terminal.append(data.subdata(in: offset..<min(data.count, offset + chunkSize)))
        }
        #expect(terminal.usesBracketedPaste == true)
        #expect(terminal.isReady == true)
        #expect(terminal.text.contains("Schreibe nur einen Python-Codeblock"))
        #expect(terminal.text.contains("print(\"Hallo\")"))
        #expect(terminal.text.contains("╭") == false)
        #expect(terminal.statusText == "system · turn 1 · ↑ 114 · ↓ 21 · 135 / 8.192 (1% used)")
        #expect(terminal.displayLines.flatMap { $0 }.contains { $0.style.dim })
    }
}
