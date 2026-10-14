import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var session: ChatSession?

    func applicationWillTerminate(_ notification: Notification) {
        session?.shutdown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
