import ChatHistory
import SwiftUI

struct ChatSidebarRow: View {
    let chat: SavedChat
    let isEditing: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onPin: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isEditing {
                Button(action: onSelect) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? .primary : .secondary)
                        chatLabel.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(chat.title), \(isSelected ? "ausgewählt" : "nicht ausgewählt")")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            } else {
                chatLabel.frame(maxWidth: .infinity, alignment: .leading)
                Button(chat.isPinned ? "Chat lösen" : "Chat anheften", systemImage: chat.isPinned ? "pin.fill" : "pin") {
                    onPin()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(chat.isPinned ? "Anheftung lösen" : "Chat oben anheften")
                .accessibilityLabel("\(chat.isPinned ? "Anheftung lösen" : "Anheften"): \(chat.title)")
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .contain)
    }

    private var chatLabel: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(chat.title).font(.body).lineLimit(2)
            if !chat.preview.isEmpty {
                Text(chat.preview).font(.callout).foregroundStyle(.secondary).lineLimit(1)
            }
            Text(chat.updatedAt, format: .dateTime.day().month().hour().minute())
                .font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
