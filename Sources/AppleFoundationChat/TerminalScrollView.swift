import AppKit

@MainActor
final class TerminalScrollView: NSScrollView {
    var onResize: ((Int, Int) -> Void)?
    private var lastSize = NSSize.zero

    override func layout() {
        super.layout()
        guard let window else { return }
        // Growing the composer only changes the visible viewport. Keep fm's row count
        // tied to the window so typing and submitting do not trigger TUI redraws.
        let size = NSSize(width: contentSize.width, height: window.contentLayoutRect.height - 64)
        guard size != lastSize, size.width > 0, size.height > 0 else { return }
        lastSize = size
        let columns = Int((size.width - 86) / TerminalTextRenderer.characterWidth)
        // fm's input box and status occupy four terminal rows, rendered natively below the scroll view.
        let rows = Int((size.height - 36) / TerminalTextRenderer.lineHeight) + 4
        onResize?(columns, rows)
    }
}
