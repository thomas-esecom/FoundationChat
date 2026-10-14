@testable import AppleFoundationChat
import Foundation
import Testing

struct PromptListEditingTests {
    @Test func convertsLineMarkerButPreservesOrdinaryHyphens() throws {
        let edit = try #require(PromptListEditing.bulletForSpace(in: "Frage 👋\n  -", selection: NSRange(location: 12, length: 0)))
        #expect(edit.text == "  • ")
        #expect(edit.range == NSRange(location: 9, length: 3))
        #expect(PromptListEditing.bulletForSpace(in: "x -", selection: NSRange(location: 3, length: 0)) == nil)
        #expect(PromptListEditing.bulletForSpace(in: "-", selection: NSRange(location: 0, length: 1)) == nil)
    }

    @Test func continuesListAtCursorAndPreservesTextAfterCursor() {
        let text = "• Erster Punkt"
        let edit = PromptListEditing.newline(in: text, selection: NSRange(location: 8, length: 0))
        let result = (text as NSString).replacingCharacters(in: edit.range, with: edit.text)
        #expect(result == "• Erster\n•  Punkt")
    }

    @Test func continuesIndentedPastedListAndSupportsEmoji() {
        let text = "Notiz 👋\n\t- Punkt 👋"
        let edit = PromptListEditing.newline(in: text, selection: NSRange(location: text.utf16.count, length: 0))
        #expect(edit.text == "\n\t• ")
        #expect(edit.range.location == text.utf16.count)
    }

    @Test func emptyBulletEndsListWithoutDeletingPreviousItem() {
        let text = "• Erster\n• "
        let edit = PromptListEditing.newline(in: text, selection: NSRange(location: text.utf16.count, length: 0))
        let result = (text as NSString).replacingCharacters(in: edit.range, with: edit.text)
        #expect(result == "• Erster\n")
    }

    @Test func insertsNewlineAtSelectionForPlainText() {
        let text = "Hallo Welt"
        let edit = PromptListEditing.newline(in: text, selection: NSRange(location: 5, length: 5))
        #expect((text as NSString).replacingCharacters(in: edit.range, with: edit.text) == "Hallo\n")
    }

    @Test func newBulletBeforeExistingContentDoesNotEndList() {
        let edit = PromptListEditing.newline(in: "• Punkt", selection: NSRange(location: 2, length: 0))
        #expect(edit.text == "\n• ")
    }
}
