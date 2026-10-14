import SwiftUI
import TerminalCore

struct TerminalOutputView: NSViewRepresentable {
    let text: NSAttributedString
    let replies: [TerminalReply]
    let onCopy: (String) -> Bool
    let onResize: (Int, Int) -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = TerminalScrollView()
        scroll.onResize = onResize
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = true
        scroll.backgroundColor = TerminalTextRenderer.background

        let view = TerminalTextView()
        view.isEditable = false
        view.isSelectable = true
        view.isRichText = true
        view.font = TerminalTextRenderer.font
        view.textColor = TerminalTextRenderer.foreground
        view.backgroundColor = TerminalTextRenderer.background
        view.textContainerInset = NSSize(width: 20, height: 18)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.textContainer?.widthTracksTextView = false
        view.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: .greatestFiniteMagnitude)
        view.setAccessibilityLabel("Terminalausgabe von fm chat")
        scroll.documentView = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? TerminalTextView else { return }
        view.updateReplies(replies, onCopy: onCopy)
        guard view.textStorage?.isEqual(to: text) != true else { return }
        let followsBottom = scroll.contentView.bounds.maxY >= view.bounds.maxY - 40
        let selection = view.selectedRange()
        view.textStorage?.setAttributedString(text)
        let length = text.length
        if followsBottom && selection.length == 0 {
            view.scrollRangeToVisible(NSRange(location: length, length: 0))
        } else if NSMaxRange(selection) <= length {
            view.setSelectedRange(selection)
        }
    }
}
