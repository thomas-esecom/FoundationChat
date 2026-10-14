import AppKit
import TerminalCore

@MainActor
final class TerminalTextView: NSTextView {
    private var replies: [TerminalReply] = []
    private var copyButtons: [NSButton] = []
    private var onCopy: ((String) -> Bool)?

    override func accessibilityChildren() -> [Any]? {
        (super.accessibilityChildren() ?? []) + copyButtons.map { $0 as Any }
    }

    func updateReplies(_ replies: [TerminalReply], onCopy: @escaping (String) -> Bool) {
        self.replies = replies
        self.onCopy = onCopy
        while copyButtons.count > replies.count { copyButtons.removeLast().removeFromSuperview() }
        while copyButtons.count < replies.count {
            let button = NSButton(image: copyImage(), target: self, action: #selector(copyReply(_:)))
            button.isBordered = false
            button.contentTintColor = .secondaryLabelColor
            button.toolTip = "Antwort als Text kopieren"
            addSubview(button)
            copyButtons.append(button)
        }
        for (index, button) in copyButtons.enumerated() {
            button.tag = index
            button.setAccessibilityLabel("Antwort \(replies[index].id + 1) kopieren")
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard let textContainer, let layoutManager else { return }
        let width = max(0, bounds.width - 2 * textContainerInset.width - 36)
        if textContainer.containerSize.width != width {
            textContainer.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        }
        layoutManager.ensureLayout(for: textContainer)
        for (reply, button) in zip(replies, copyButtons) {
            guard reply.range.location < (string as NSString).length else { button.isHidden = true; continue }
            let glyphs = layoutManager.glyphRange(forCharacterRange: NSRange(location: reply.range.location, length: 1), actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
            button.isHidden = false
            button.frame = NSRect(x: bounds.width - 44, y: textContainerInset.height + rect.minY - 4, width: 24, height: 24)
        }
    }

    @objc private func copyReply(_ sender: NSButton) {
        guard replies.indices.contains(sender.tag) else { return }
        guard onCopy?(replies[sender.tag].text) == true else { return }
        sender.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Kopiert")
        sender.toolTip = "Kopiert"
        sender.setAccessibilityLabel("Antwort \(replies[sender.tag].id + 1) kopiert")
        Task { [weak self, weak sender] in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            guard let self, let sender else { return }
            sender.image = self.copyImage()
            sender.toolTip = "Antwort als Text kopieren"
            if self.replies.indices.contains(sender.tag) {
                sender.setAccessibilityLabel("Antwort \(self.replies[sender.tag].id + 1) kopieren")
            }
        }
    }

    private func copyImage() -> NSImage {
        NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Antwort kopieren") ?? NSImage()
    }
}
