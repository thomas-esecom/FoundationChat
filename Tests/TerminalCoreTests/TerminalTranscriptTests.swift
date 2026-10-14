import Foundation
import Testing
@testable import TerminalCore

struct TerminalTranscriptTests {
    @Test func splitUTF8PreservesGermanAndEmoji() {
        var terminal = TerminalTranscript()
        let bytes = Data("Grüße 👋\r\nyou> ".utf8)
        for byte in bytes { terminal.append(Data([byte])) }
        #expect(terminal.text == "Grüße 👋\nyou> ")
    }

    @Test func carriageReturnAndEraseReplaceProgress() {
        var terminal = TerminalTranscript()
        terminal.append(Data("Wird geladen …\r\u{1B}[2KHallo\r\n".utf8))
        #expect(terminal.text == "Hallo\n")
    }

    @Test func splitANSIAndOSCDoNotLeakIntoTranscript() {
        var terminal = TerminalTranscript()
        for part in ["\u{1B}[38;2;55", ";195;160mfm", "\u{1B}[0m> ", "\u{1B}]0;Fenstertitel", "\u{1B}", "\\Hallo"] {
            terminal.append(Data(part.utf8))
        }
        #expect(terminal.text == "fm> Hallo")
    }

    @Test func cursorMovementUpdatesExistingLine() {
        var terminal = TerminalTranscript()
        terminal.append(Data("Alt\r\nyou> \u{1B}[1A\rNeu\u{1B}[1B\r".utf8))
        #expect(terminal.text == "Neu\nyou> ")
    }

    @Test func scrollbackIsBounded() {
        var terminal = TerminalTranscript(maximumLines: 3)
        terminal.append(Data("1\n2\n3\n4".utf8))
        #expect(terminal.text == "2\n3\n4")
    }

    @Test func clearingDuringIncompleteUTF8PreservesNextCharacter() {
        var terminal = TerminalTranscript()
        terminal.append(Data([0xC3]))
        terminal.clear()
        terminal.append(Data([0xBC]))
        #expect(terminal.text == "ü")
    }

    @Test func invalidAndTruncatedUTF8AreVisibleAsReplacementCharacters() {
        var terminal = TerminalTranscript()
        terminal.append(Data([0xFF, 0xC3]))
        terminal.finish()
        #expect(terminal.text == "��")
    }

    @Test func oversizedCursorControlsRemainBounded() {
        var terminal = TerminalTranscript(maximumLines: 3)
        terminal.append(Data("\u{1B}[999999B\u{1B}[999999CHallo\rOK".utf8))
        #expect(terminal.text == "\n\nOK")
    }
}
