import Foundation

enum PromptListEditing {
    static func bulletForSpace(in text: String, selection: NSRange) -> (range: NSRange, text: String)? {
        let value = text as NSString
        guard selection.length == 0, selection.location <= value.length else { return nil }
        let line = value.lineRange(for: selection)
        let prefix = value.substring(with: NSRange(location: line.location, length: selection.location - line.location))
        let indentation = String(prefix.prefix { $0 == " " || $0 == "\t" })
        guard prefix == indentation + "-" else { return nil }
        return (NSRange(location: line.location, length: prefix.utf16.count), indentation + "• ")
    }

    static func newline(in text: String, selection: NSRange) -> (range: NSRange, text: String) {
        let value = text as NSString
        guard NSMaxRange(selection) <= value.length else { return (NSRange(location: value.length, length: 0), "\n") }
        let line = value.lineRange(for: NSRange(location: selection.location, length: 0))
        let prefix = value.substring(with: NSRange(location: line.location, length: selection.location - line.location))
        let indentation = String(prefix.prefix { $0 == " " || $0 == "\t" })
        let content = prefix.dropFirst(indentation.count)
        guard content.hasPrefix("• ") || content.hasPrefix("- ") else { return (selection, "\n") }
        let wholeLine = value.substring(with: line).trimmingCharacters(in: .newlines)
        if selection.length == 0, wholeLine.dropFirst(indentation.count + 2).trimmingCharacters(in: .whitespaces).isEmpty {
            return (NSRange(location: line.location, length: selection.location - line.location), indentation)
        }
        return (selection, "\n" + indentation + "• ")
    }
}
