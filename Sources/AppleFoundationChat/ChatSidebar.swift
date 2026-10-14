import ChatHistory
import SwiftUI

struct ChatSidebar: View {
    @Bindable var session: ChatSession
    @State private var query = ""
    @State private var selectedID: String?
    @State private var isEditing = false
    @State private var selectedForDeletion: Set<String> = []

    private var filteredChats: [SavedChat] {
        session.savedChats.filter { query.isEmpty || $0.title.localizedStandardContains(query) || $0.preview.localizedStandardContains(query) }
    }

    private var isBusy: Bool { session.isUpdatingHistory || (session.isRunning && !session.canSend) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Chats").font(.headline)
                Spacer()
                Button(isEditing ? "Fertig" : "Edit") {
                    isEditing.toggle()
                    selectedForDeletion.removeAll()
                }
                .buttonStyle(.plain)
                .help(isEditing ? "Chat-Auswahl beenden" : "Chats zum Löschen auswählen")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            List(selection: Binding(get: { isEditing ? nil : selectedID }, set: { if !isEditing { selectedID = $0 } })) {
                if session.savedChats.isEmpty {
                    ContentUnavailableView("Noch keine Chats", systemImage: "bubble.left.and.bubble.right",
                        description: Text("Gespeicherte Gespräche erscheinen hier automatisch."))
                } else {
                    let pinned = filteredChats.filter(\.isPinned)
                    let other = filteredChats.filter { !$0.isPinned }
                    ForEach(pinned) { chat in sidebarRow(chat) }
                    if !pinned.isEmpty && !other.isEmpty {
                        Divider()
                            .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                            .accessibilityLabel("Weitere Chats")
                    }
                    ForEach(other) { chat in sidebarRow(chat) }
                }
                if let error = session.historyError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            .listStyle(.sidebar)

            if isEditing {
                Divider()
                Button("Löschen (\(selectedForDeletion.count))", systemImage: "trash", role: .destructive) {
                    let ids = selectedForDeletion
                    Task {
                        let deleted = await session.deleteChats(ids)
                        selectedForDeletion.subtract(deleted)
                    }
                }
                .disabled(selectedForDeletion.isEmpty)
                .help("Ausgewählte Chats in den Papierkorb verschieben")
                .padding(12)
            }
        }
        .disabled(isBusy)
        .searchable(text: $query, prompt: "Chats suchen")
        .navigationTitle("Chats")
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        .onChange(of: selectedID) {
            if !isEditing, let selectedID, selectedID != session.activeChatID { session.start(resuming: selectedID) }
        }
        .onChange(of: session.activeChatID) { selectedID = session.activeChatID }
        .onChange(of: session.savedChats) { selectedForDeletion.formIntersection(Set(session.savedChats.map(\.id))) }
        .task {
            selectedID = session.activeChatID
            while !Task.isCancelled {
                await session.refreshHistory()
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }

    private func sidebarRow(_ chat: SavedChat) -> some View {
        ChatSidebarRow(chat: chat, isEditing: isEditing, isSelected: selectedForDeletion.contains(chat.id),
            onSelect: {
                if !selectedForDeletion.insert(chat.id).inserted { selectedForDeletion.remove(chat.id) }
            }, onPin: { Task { await session.togglePin(chat) } })
            .tag(chat.id)
    }
}
