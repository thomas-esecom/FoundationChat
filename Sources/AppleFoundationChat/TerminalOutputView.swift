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
        context.coordinator.scroll = scroll
        scroll.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.boundsChanged(_:)),
            name: NSView.boundsDidChangeNotification, object: scroll.contentView)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? TerminalTextView else { return }
        view.updateReplies(replies, onCopy: onCopy)
        guard view.textStorage?.isEqual(to: text) != true else { return }
        let coordinator = context.coordinator
        coordinator.isUpdating = true
        defer {
            coordinator.lastBounds = scroll.contentView.bounds
            coordinator.isUpdating = false
        }
        let selection = view.selectedRange()
        view.textStorage?.setAttributedString(text)
        // Lay out and size the document before scrolling; NSTextView otherwise uses
        // the preceding frame while the streamed response is still growing.
        view.setFrameSize(NSSize(width: scroll.contentSize.width, height: view.frame.height))
        view.layoutSubtreeIfNeeded()
        if let container = view.textContainer, let manager = view.layoutManager {
            manager.ensureLayout(for: container)
            let contentHeight = max(manager.usedRect(for: container).maxY, manager.extraLineFragmentRect.maxY)
            view.setFrameSize(NSSize(width: scroll.contentSize.width,
                height: max(scroll.contentSize.height, ceil(contentHeight + 2 * view.textContainerInset.height))))
        }
        let length = text.length
        if coordinator.followsOutput && selection.length == 0 {
            scroll.contentView.scroll(to: NSPoint(x: 0, y: max(0, view.frame.height - scroll.contentSize.height)))
            scroll.reflectScrolledClipView(scroll.contentView)
        } else if NSMaxRange(selection) <= length {
            view.setSelectedRange(selection)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor
    final class Coordinator: NSObject {
        weak var scroll: NSScrollView?
        var followsOutput = true
        var isUpdating = false
        var lastBounds = NSRect.zero

        @objc func boundsChanged(_ notification: Notification) {
            guard let scroll else { return }
            let bounds = scroll.contentView.bounds
            defer { lastBounds = bounds }
            guard !isUpdating, bounds.size == lastBounds.size, bounds.origin != lastBounds.origin,
                  let document = scroll.documentView else { return }
            followsOutput = bounds.maxY >= document.frame.maxY - 40
        }

        deinit { NotificationCenter.default.removeObserver(self) }
    }
}
