import Foundation

/// A bounded transcript for line-oriented CLIs, including streaming UTF-8 and ANSI controls.
/// This is deliberately not a full-screen VT terminal emulator.
public struct TerminalTranscript {
    private enum EscapeState {
        case text, escape, csi, osc, oscEscape, ignoredString, ignoredStringEscape
    }

    private var lines: [[Unicode.Scalar]] = [[]]
    private var row = 0
    private var column = 0
    private var savedCursor = (row: 0, column: 0)
    private var escapeState = EscapeState.text
    private var control = ""
    private var pendingUTF8: [UInt8] = []
    private let maximumLines: Int
    private let maximumColumns = 4096

    public init(maximumLines: Int = 2500) {
        self.maximumLines = max(2, maximumLines)
    }

    public var text: String {
        lines.map { String(String.UnicodeScalarView($0)) }.joined(separator: "\n")
    }

    public mutating func clear() {
        lines = [[]]
        row = 0
        column = 0
        savedCursor = (0, 0)
        // Preserve decoder state: an output chunk may end in the middle of UTF-8 or ANSI.
    }

    public mutating func append(_ data: Data) {
        pendingUTF8.append(contentsOf: data)
        var completeCount = pendingUTF8.count
        // Keep an incomplete trailing UTF-8 sequence for the next chunk.
        if let start = pendingUTF8.indices.reversed().prefix(4).first(where: {
            pendingUTF8[$0] & 0xC0 != 0x80
        }) {
            let byte = pendingUTF8[start]
            let expected = byte < 0x80 ? 1 : byte & 0xE0 == 0xC0 ? 2 :
                byte & 0xF0 == 0xE0 ? 3 : byte & 0xF8 == 0xF0 ? 4 : 1
            if pendingUTF8.count - start < expected { completeCount = start }
        }
        let decoded = String(decoding: pendingUTF8.prefix(completeCount), as: UTF8.self)
        pendingUTF8.removeFirst(completeCount)
        for scalar in decoded.unicodeScalars { consume(scalar) }
    }

    public mutating func finish() {
        for scalar in String(decoding: pendingUTF8, as: UTF8.self).unicodeScalars { consume(scalar) }
        pendingUTF8.removeAll()
        escapeState = .text
        control = ""
    }

    private mutating func consume(_ scalar: Unicode.Scalar) {
        switch escapeState {
        case .escape:
            switch scalar {
            case "[": escapeState = .csi; control = ""
            case "]": escapeState = .osc
            case "P", "^", "_": escapeState = .ignoredString
            case "7": savedCursor = (row, column); escapeState = .text
            case "8": row = min(savedCursor.row, lines.count - 1); column = savedCursor.column; escapeState = .text
            default: escapeState = .text
            }
        case .csi:
            if (0x40...0x7E).contains(scalar.value) {
                performControl(scalar)
                escapeState = .text
            } else if control.utf8.count < 128 {
                control.unicodeScalars.append(scalar)
            } else {
                escapeState = .text
            }
        case .osc, .ignoredString:
            if scalar.value == 7 { escapeState = .text }
            else if scalar.value == 27 {
                escapeState = escapeState == .osc ? .oscEscape : .ignoredStringEscape
            }
        case .oscEscape, .ignoredStringEscape:
            if scalar == "\\" { escapeState = .text }
            else { escapeState = escapeState == .oscEscape ? .osc : .ignoredString }
        case .text:
            switch scalar.value {
            case 27: escapeState = .escape
            case 13: column = 0
            case 10: moveToRow(row + 1); column = 0
            case 8: column = max(0, column - 1)
            case 9:
                let target = min(maximumColumns, (column / 8 + 1) * 8)
                while column < target { put(" ") }
            case 0...31, 127: break
            default: put(scalar)
            }
        }
    }

    private mutating func put(_ scalar: Unicode.Scalar) {
        guard column < maximumColumns else { return }
        while lines[row].count < column { lines[row].append(" ") }
        if column < lines[row].count { lines[row][column] = scalar }
        else { lines[row].append(scalar) }
        column += 1
    }

    private mutating func moveToRow(_ target: Int) {
        row = min(maximumLines, max(0, target))
        while lines.count <= row { lines.append([]) }
        if lines.count > maximumLines {
            let removed = lines.count - maximumLines
            lines.removeFirst(removed)
            row -= removed
            savedCursor.row = max(0, savedCursor.row - removed)
        }
    }

    private mutating func performControl(_ final: Unicode.Scalar) {
        let values = control.split(separator: ";", omittingEmptySubsequences: false).map { Int($0) ?? 0 }
        let first = values.first ?? 0
        let distance = min(maximumColumns, max(1, first))
        switch final {
        case "A": row = max(0, row - distance)
        case "B": moveToRow(row + distance)
        case "C": column = min(maximumColumns, column + distance)
        case "D": column = max(0, column - distance)
        case "G": column = min(maximumColumns, distance - 1)
        case "H", "f":
            moveToRow(max(1, first) - 1)
            column = min(maximumColumns, max(1, values.dropFirst().first ?? 1) - 1)
        case "K":
            if first == 2 { lines[row] = [] }
            else if first == 1 {
                for index in 0..<min(column + 1, lines[row].count) { lines[row][index] = " " }
            } else if column < lines[row].count { lines[row].removeSubrange(column...) }
        case "J":
            if first == 2 || first == 3 { clear() }
            else if first == 0 {
                if column < lines[row].count { lines[row].removeSubrange(column...) }
                if row + 1 < lines.count { lines.removeSubrange((row + 1)...) }
            }
        case "s": savedCursor = (row, column)
        case "u": row = min(savedCursor.row, lines.count - 1); column = savedCursor.column
        default: break // Styling, cursor visibility, and device queries do not belong in the transcript.
        }
    }
}
