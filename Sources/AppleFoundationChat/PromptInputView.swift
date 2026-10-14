import SwiftUI

struct PromptInputView: NSViewRepresentable {
    @Binding var text: String
    let isEnabled: Bool
    let focusRequest: Int
    let onHeightChange: (CGFloat) -> Void
    let onSubmit: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false

        let view = PromptTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        view.isRichText = false
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        view.textColor = .white
        view.insertionPointColor = .white
        view.drawsBackground = false
        view.textContainerInset = NSSize(width: 0, height: 4)
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.textContainer?.containerSize = NSSize(width: 200, height: CGFloat.greatestFiniteMagnitude)
        view.isVerticallyResizable = true
        view.isHorizontallyResizable = false
        view.autoresizingMask = [.width]
        view.delegate = context.coordinator
        view.setAccessibilityLabel("Chatnachricht")
        view.setAccessibilityHelp("Enter sendet. Shift-Enter fügt einen Umbruch ein. Bindestrich und Leerzeichen beginnen eine Aufzählung.")
        scroll.documentView = view
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? PromptTextView else { return }
        context.coordinator.parent = self
        view.onSubmit = onSubmit
        view.onHeightChange = onHeightChange
        view.isEditable = isEnabled
        if view.string != text {
            view.string = text
            view.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
        }
        view.updateHeight()
        if isEnabled, context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            DispatchQueue.main.async { [weak view] in
                guard let view, view.isEditable else { return }
                view.window?.makeFirstResponder(view)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: PromptInputView
        var lastFocusRequest: Int?

        init(_ parent: PromptInputView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? PromptTextView else { return }
            parent.text = view.string
            view.updateHeight()
        }
    }
}
