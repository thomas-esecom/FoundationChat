import Foundation

/// Screen coordinates, scrollback and ANSI styling for fm's interactive terminal UI.
public struct TerminalScreen {
    private enum State { case text, escape, csi, osc, oscEscape, ignored, ignoredEscape }
    private var state = State.text
    private var sequence = ""
    private var pendingUTF8 = Data()
    private var replies = Data()
    private var style = TerminalStyle()
    private var screen: [[TerminalCell]]
    private var history: [[TerminalCell]] = []
    private var row = 0
    private var column = 0
    private var saved = (row: 0, column: 0)
    private var scrollTop = 0
    private var scrollBottom: Int
    private var lastStatus = ""
    public private(set) var columns: Int
    public private(set) var rows: Int
    public private(set) var usesBracketedPaste = false

    public init(columns: Int = 120, rows: Int = 40) {
        self.columns = max(10, min(300, columns))
        self.rows = max(6, min(150, rows))
        screen = Array(repeating: [], count: self.rows)
        scrollBottom = self.rows - 1
    }

    private var paneStart: Int? {
        screen.lastIndex { line in line.map(\.text).joined().trimmingCharacters(in: .whitespaces).hasPrefix("╭─") }
    }

    public var isReady: Bool {
        if let start = paneStart, start + 1 < screen.count {
            return screen[start + 1].map(\.text).joined().trimmingCharacters(in: .whitespaces).hasPrefix("│ >")
        }
        return !usesBracketedPaste && text.hasSuffix("you>")
    }

    public var displayLines: [[TerminalCell]] {
        let end = paneStart ?? screen.count
        var lines = history + screen.prefix(end).map(Self.trimmed)
        while lines.last?.isEmpty == true { lines.removeLast() }
        while lines.first?.isEmpty == true { lines.removeFirst() }
        return lines
    }

    public var text: String { displayLines.map { $0.map(\.text).joined() }.joined(separator: "\n") }
    public var statusText: String { lastStatus }

    public mutating func resize(columns: Int, rows: Int) {
        self.columns = max(10, min(300, columns))
        let count = max(6, min(150, rows))
        // fm fully re-renders its conversation on SIGWINCH. Retaining the old screen
        // in scrollback would duplicate the conversation and leak the previous input pane.
        screen = Array(repeating: [], count: count)
        history.removeAll()
        row = 0
        column = 0
        saved = (0, 0)
        self.rows = count
        scrollTop = 0
        scrollBottom = count - 1
    }

    public mutating func clearDisplay() {
        history.removeAll()
        screen = Array(repeating: [], count: rows)
    }

    public mutating func takeReplies() -> Data {
        let result = replies
        replies.removeAll(keepingCapacity: true)
        return result
    }

    public mutating func append(_ data: Data) {
        pendingUTF8.append(data)
        var complete = pendingUTF8.count
        if let start = pendingUTF8.indices.reversed().prefix(4).first(where: { pendingUTF8[$0] & 0xC0 != 0x80 }) {
            let byte = pendingUTF8[start]
            let expected = byte < 0x80 ? 1 : byte & 0xE0 == 0xC0 ? 2 : byte & 0xF0 == 0xE0 ? 3 : byte & 0xF8 == 0xF0 ? 4 : 1
            if pendingUTF8.count - start < expected { complete = start }
        }
        let text = String(decoding: pendingUTF8.prefix(complete), as: UTF8.self)
        pendingUTF8 = Data(pendingUTF8.dropFirst(complete))
        for scalar in text.unicodeScalars { consume(scalar) }
        // Status redraws replace an existing line. Keep only the latest real fm status.
        if let start = paneStart {
            for line in screen.dropFirst(start + 1) {
                let value = line.map(\.text).joined().trimmingCharacters(in: .whitespaces)
                if value == "system" || value.hasPrefix("system ·") { lastStatus = value }
            }
        }
    }

    public mutating func finish() {
        for scalar in String(decoding: pendingUTF8, as: UTF8.self).unicodeScalars { consume(scalar) }
        pendingUTF8.removeAll()
    }

    private static func trimmed(_ line: [TerminalCell]) -> [TerminalCell] {
        var result = line
        while let last = result.last, (last.text == " " || last.text.isEmpty), last.style.background == nil {
            result.removeLast()
        }
        return result
    }

    private mutating func consume(_ scalar: Unicode.Scalar) {
        switch state {
        case .text:
            switch scalar.value {
            case 27: state = .escape
            case 13: column = 0
            case 10: newline()
            case 8: column = max(0, column - 1)
            case 9: column = min(columns, (column / 8 + 1) * 8)
            case 0...31, 127: break
            default: put(scalar)
            }
        case .escape:
            switch scalar {
            case "[": state = .csi; sequence = ""
            case "]": state = .osc; sequence = ""
            case "P", "^", "_": state = .ignored
            case "7": saved = (row, column); state = .text
            case "8": row = min(rows - 1, saved.row); column = min(columns, saved.column); state = .text
            case "D": newline(); state = .text
            case "M":
                if row == scrollTop { scrollDown(1) } else { row = max(0, row - 1) }
                state = .text
            default: state = .text
            }
        case .csi:
            if (0x40...0x7E).contains(scalar.value) { control(scalar); state = .text }
            else if sequence.utf8.count < 256 { sequence.unicodeScalars.append(scalar) }
            else { state = .text }
        case .osc:
            if scalar.value == 7 { osc(); state = .text }
            else if scalar.value == 27 { state = .oscEscape }
            else if sequence.utf8.count < 1024 { sequence.unicodeScalars.append(scalar) }
        case .oscEscape:
            if scalar == "\\" { osc(); state = .text } else { state = .osc }
        case .ignored:
            if scalar.value == 27 { state = .ignoredEscape }
        case .ignoredEscape:
            state = scalar == "\\" ? .text : .ignored
        }
    }

    private mutating func put(_ scalar: Unicode.Scalar) {
        let category = scalar.properties.generalCategory
        let combining = category == .nonspacingMark || category == .enclosingMark || scalar.value == 0x200D
        if combining, column > 0, column - 1 < screen[row].count {
            var previous = min(column - 1, screen[row].count - 1)
            if screen[row][previous].text.isEmpty && previous > 0 { previous -= 1 }
            screen[row][previous].text.unicodeScalars.append(scalar)
            return
        }
        let wide = scalar.properties.isEmojiPresentation || (0x2E80...0xA4CF).contains(scalar.value) ||
            (0xAC00...0xD7A3).contains(scalar.value) || (0xF900...0xFAFF).contains(scalar.value) ||
            (0xFF01...0xFF60).contains(scalar.value) || (0x20000...0x3FFFF).contains(scalar.value)
        let width = wide ? 2 : 1
        if column + width > columns { column = 0; newline() }
        while screen[row].count < column + width { screen[row].append(TerminalCell()) }
        screen[row][column] = TerminalCell(text: String(scalar), style: style)
        if wide { screen[row][column + 1] = TerminalCell(text: "", style: style) }
        column += width
    }

    private mutating func newline() {
        if row == scrollBottom { scrollUp(1) }
        else { row = min(rows - 1, row + 1) }
    }

    private mutating func scrollUp(_ count: Int) {
        let amount = min(scrollBottom - scrollTop + 1, max(1, count))
        if scrollTop == 0 { history.append(contentsOf: screen.prefix(amount).map(Self.trimmed)); boundHistory() }
        screen.removeSubrange(scrollTop..<(scrollTop + amount))
        screen.insert(contentsOf: repeatElement([], count: amount), at: scrollBottom - amount + 1)
    }

    private mutating func scrollDown(_ count: Int) {
        let amount = min(scrollBottom - scrollTop + 1, max(1, count))
        screen.removeSubrange((scrollBottom - amount + 1)...scrollBottom)
        screen.insert(contentsOf: repeatElement([], count: amount), at: scrollTop)
    }

    private mutating func boundHistory() {
        while history.first?.isEmpty == true { history.removeFirst() }
        if history.count > 2500 { history.removeFirst(history.count - 2500) }
    }

    private mutating func osc() {
        if sequence == "11;?" { replies.append(Data("\u{1B}]11;rgb:2020/2020/2020\u{1B}\\".utf8)) }
        if sequence == "10;?" { replies.append(Data("\u{1B}]10;rgb:eeee/eeee/eeee\u{1B}\\".utf8)) }
    }

    private mutating func control(_ final: Unicode.Scalar) {
        let values = sequence.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
        let first = values.first ?? 0
        let distance = min(4096, max(1, first))
        if sequence.hasPrefix("?") {
            if sequence == "?2004" { usesBracketedPaste = final == "h" }
            return
        }
        switch final {
        case "m": setStyle(values)
        case "A": row = max(0, row - distance)
        case "B": row = min(rows - 1, row + distance)
        case "C": column = min(columns, column + distance)
        case "D": column = max(0, column - distance)
        case "G": column = min(columns - 1, distance - 1)
        case "H", "f": row = min(rows - 1, max(1, first) - 1); column = min(columns - 1, max(1, values.dropFirst().first ?? 1) - 1)
        case "K":
            if first == 2 { screen[row] = [] }
            else if first == 1 {
                for index in 0..<min(column + 1, screen[row].count) { screen[row][index] = TerminalCell(style: style) }
            } else if column < screen[row].count { screen[row].removeSubrange(column...) }
        case "J":
            if first == 2 { screen = Array(repeating: [], count: rows) }
            else if first == 3 { history.removeAll() }
            else if first == 0 {
                if column < screen[row].count { screen[row].removeSubrange(column...) }
                if row + 1 < rows { for index in (row + 1)..<rows { screen[index] = [] } }
            }
        case "S": scrollUp(distance)
        case "T": scrollDown(distance)
        case "r":
            scrollTop = min(rows - 2, max(1, first) - 1)
            scrollBottom = min(rows - 1, max(scrollTop + 2, values.dropFirst().first ?? rows) - 1)
            row = 0; column = 0
        case "s": saved = (row, column)
        case "u": row = min(rows - 1, saved.row); column = min(columns, saved.column)
        case "n":
            if first == 6 { replies.append(Data("\u{1B}[\(row + 1);\(min(column, columns - 1) + 1)R".utf8)) }
        case "c": replies.append(Data("\u{1B}[?1;2c".utf8))
        default: break
        }
    }

    private mutating func setStyle(_ values: [Int]) {
        var index = 0
        while index < values.count {
            let value = values[index]
            switch value {
            case 0: style = TerminalStyle()
            case 1: style.bold = true
            case 2: style.dim = true
            case 3: style.italic = true
            case 4: style.underline = true
            case 7: style.inverse = true
            case 22: style.bold = false; style.dim = false
            case 23: style.italic = false
            case 24: style.underline = false
            case 27: style.inverse = false
            case 39: style.foreground = nil
            case 49: style.background = nil
            case 38, 48:
                if index + 4 < values.count, values[index + 1] == 2 {
                    let components = values[(index + 2)...(index + 4)].map { UInt32(max(0, min(255, $0))) }
                    let color = components[0] << 16 | components[1] << 8 | components[2]
                    if value == 38 { style.foreground = color } else { style.background = color }
                    index += 4
                } else if index + 2 < values.count, values[index + 1] == 5 {
                    let color = Self.palette(values[index + 2])
                    if value == 38 { style.foreground = color } else { style.background = color }
                    index += 2
                }
            case 30...37: style.foreground = Self.palette(value - 30)
            case 90...97: style.foreground = Self.palette(value - 90 + 8)
            case 40...47: style.background = Self.palette(value - 40)
            case 100...107: style.background = Self.palette(value - 100 + 8)
            default: break
            }
            index += 1
        }
    }

    private static func palette(_ index: Int) -> UInt32 {
        let colors: [UInt32] = [0x202020, 0xCD3131, 0x0DBC79, 0xE5E510, 0x2472C8, 0xBC3FBC, 0x11A8CD, 0xEEEEEE,
                                0x666666, 0xF14C4C, 0x23D18B, 0xF5F543, 0x3B8EEA, 0xD670D6, 0x29B8DB, 0xFFFFFF]
        if index < 16 { return colors[max(0, index)] }
        if index >= 232 {
            let value = UInt32(min(255, 8 + (min(255, index) - 232) * 10))
            return value << 16 | value << 8 | value
        }
        let cube = index - 16
        let levels: [UInt32] = [0, 95, 135, 175, 215, 255]
        return levels[cube / 36] << 16 | levels[cube / 6 % 6] << 8 | levels[cube % 6]
    }
}
