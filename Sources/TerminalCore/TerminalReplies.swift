import Foundation

public enum TerminalReplies {
    public static func extract(from lines: [[TerminalCell]], lastReplyComplete: Bool) -> [TerminalReply] {
        let strings = lines.map { $0.map(\.text).joined() }
        var offset = 0
        let offsets = strings.map { value in
            defer { offset += value.utf16.count + 1 }
            return offset
        }
        let prompts = lines.indices.filter { index in
            strings[index].trimmingCharacters(in: .whitespaces).hasPrefix("> ") &&
                lines[index].contains { $0.style.background != nil }
        }
        var replies: [TerminalReply] = []
        for (number, prompt) in prompts.enumerated() {
            if number == prompts.count - 1 && !lastReplyComplete { continue }
            let next = number + 1 < prompts.count ? prompts[number + 1] : lines.count
            let backgrounds = Set(lines[prompt].compactMap(\.style.background))
            var start = prompt + 1
            while start < next && (strings[start].trimmingCharacters(in: .whitespaces).isEmpty ||
                lines[start].contains { cell in cell.style.background.map { backgrounds.contains($0) } ?? false }) {
                start += 1
            }
            var end = next
            while end > start && strings[end - 1].trimmingCharacters(in: .whitespaces).isEmpty { end -= 1 }
            guard start < end else { continue }
            let text = strings[start..<end].map { value in
                var result = value
                while result.last?.isWhitespace == true { result.removeLast() }
                return result
            }.joined(separator: "\n")
            let rangeEnd = offsets[end - 1] + strings[end - 1].utf16.count
            replies.append(TerminalReply(id: number, range: NSRange(location: offsets[start], length: rangeEnd - offsets[start]), text: text))
        }
        return replies
    }
}
