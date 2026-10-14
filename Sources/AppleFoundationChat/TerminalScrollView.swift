import AppKit

@MainActor
final class TerminalScrollView: NSScrollView {
    var onResize: ((Int, Int) -> Void)?
    private var lastSize = NSSize.zero

    override func layout() {
        super.layout()
        let size = contentSize
        guard size != lastSize, size.width > 0, size.height > 0 else { return }
        lastSize = size
        let columns = Int((size.width - 86) / TerminalTextRenderer.characterWidth)
        // fm's input box and status occupy four terminal rows, rendered natively below the scroll view.
        let rows = Int((size.height - 36) / TerminalTextRenderer.lineHeight) + 4
        onResize?(columns, rows)
    }
}
