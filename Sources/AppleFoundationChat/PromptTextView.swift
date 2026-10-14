import AppKit

@MainActor
final class PromptTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onHeightChange: ((CGFloat) -> Void)?
    private var lastHeight: CGFloat = 0

    override func keyDown(with event: NSEvent) {
        guard !hasMarkedText() else { super.keyDown(with: event); return }
        if event.keyCode == 36 || event.keyCode == 76 {
            if event.modifierFlags.contains(.shift) {
                let edit = PromptListEditing.newline(in: string, selection: selectedRange())
                insertText(edit.text, replacementRange: edit.range)
            } else {
                onSubmit?()
            }
            return
        }
        if event.characters == " ", !event.modifierFlags.contains(.command),
           let edit = PromptListEditing.bulletForSpace(in: string, selection: selectedRange()) {
            insertText(edit.text, replacementRange: edit.range)
            return
        }
        super.keyDown(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if string.isEmpty {
            ("Leg los..." as NSString).draw(at: NSPoint(x: textContainerInset.width + (textContainer?.lineFragmentPadding ?? 0), y: textContainerInset.height),
                withAttributes: [.font: font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular), .foregroundColor: NSColor.gray])
        }
    }

    override func layout() {
        super.layout()
        updateHeight()
    }

    func updateHeight() {
        needsDisplay = true
        guard let textContainer, let layoutManager else { return }
        layoutManager.ensureLayout(for: textContainer)
        let contentHeight = max(layoutManager.usedRect(for: textContainer).maxY, layoutManager.extraLineFragmentRect.maxY)
        let height = min(160, max(24, ceil(contentHeight + 2 * textContainerInset.height)))
        guard height != lastHeight else { return }
        lastHeight = height
        // Layout can run during a SwiftUI update; publish the measured height afterwards.
        DispatchQueue.main.async { [weak self] in self?.onHeightChange?(height) }
    }
}
