import AppKit
import TerminalCore

@MainActor
enum TerminalTextRenderer {
    static let font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
    static let background = NSColor(srgbRed: 0.125, green: 0.125, blue: 0.125, alpha: 1)
    static let foreground = NSColor(srgbRed: 0.93, green: 0.93, blue: 0.93, alpha: 1)
    static var characterWidth: Double { ("M" as NSString).size(withAttributes: [.font: font]).width }
    static var lineHeight: Double { NSLayoutManager().defaultLineHeight(for: font) + 3 }

    static func render(_ lines: [[TerminalCell]]) -> NSAttributedString {
        let result = NSMutableAttributedString(string: "")
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        for (index, line) in lines.enumerated() {
            if index > 0 { result.append(NSAttributedString(string: "\n", attributes: [.font: font, .paragraphStyle: paragraph])) }
            var segment = ""
            var previous = TerminalStyle()
            for cell in line {
                if cell.style != previous, !segment.isEmpty {
                    result.append(NSAttributedString(string: segment, attributes: attributes(previous, paragraph: paragraph)))
                    segment = ""
                }
                segment += cell.text
                previous = cell.style
            }
            if !segment.isEmpty { result.append(NSAttributedString(string: segment, attributes: attributes(previous, paragraph: paragraph))) }
        }
        return result
    }

    private static func attributes(_ style: TerminalStyle, paragraph: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
        var face = style.bold ? NSFont.monospacedSystemFont(ofSize: font.pointSize, weight: .bold) : font
        if style.italic { face = NSFontManager.shared.convert(face, toHaveTrait: .italicFontMask) }
        var ink = style.foreground.map(color) ?? foreground
        var fill = style.background.map(color)
        if style.dim { ink = NSColor(srgbRed: 0.65, green: 0.65, blue: 0.65, alpha: 1) }
        if style.inverse { let old = ink; ink = fill ?? background; fill = old }
        var attributes: [NSAttributedString.Key: Any] = [.font: face, .foregroundColor: ink, .paragraphStyle: paragraph]
        if let fill { attributes[.backgroundColor] = fill }
        if style.dim { attributes[.backgroundColor] = fill ?? NSColor(srgbRed: 0.16, green: 0.16, blue: 0.16, alpha: 1) }
        if style.underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        return attributes
    }

    private static func color(_ rgb: UInt32) -> NSColor {
        NSColor(srgbRed: Double(rgb >> 16 & 255) / 255, green: Double(rgb >> 8 & 255) / 255,
                blue: Double(rgb & 255) / 255, alpha: 1)
    }
}
