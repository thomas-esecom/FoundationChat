import SwiftUI

@main
struct AppleFoundationChatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var session = ChatSession()

    var body: some Scene {
        Window("FoundationChat", id: "chat") {
            NavigationSplitView {
                ChatSidebar(session: session)
            } detail: {
                ContentView(session: session)
            }
                .frame(minWidth: 860, minHeight: 420)
                .preferredColorScheme(.dark)
                .task { appDelegate.session = session }
        }
        .defaultSize(width: 1100, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Neuer Chat") { session.start() }
                    .keyboardShortcut("n")
                Button("Letzten Chat fortsetzen") { session.start(continuing: true) }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            CommandMenu("Chat") {
                Button("Unterbrechen", action: session.interrupt)
                    .keyboardShortcut("c", modifiers: [.control])
                    .disabled(!session.isRunning)
                Button("Chat beenden", action: session.stop)
                    .disabled(!session.isRunning)
                Divider()
                Button("Anzeige leeren", action: session.clearOutput)
                    .keyboardShortcut("k")
                Button("Ausgabe kopieren", action: session.copyOutput)
                Button("Als Text exportieren …", action: session.exportOutput)
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }
}
