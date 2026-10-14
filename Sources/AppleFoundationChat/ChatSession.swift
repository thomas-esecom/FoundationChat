import AppKit
import ChatHistory
import Darwin
import DocumentSupport
import Observation
import TerminalCore

@MainActor
@Observable
final class ChatSession {
    private(set) var output = ""
    private(set) var styledOutput = NSAttributedString(string: "")
    private(set) var replies: [TerminalReply] = []
    private(set) var modelStatus = ""
    private(set) var canSend = false
    private(set) var document: ChatDocument?
    private(set) var isLoadingDocument = false
    private(set) var isRunning = false
    private(set) var savedChats: [SavedChat] = []
    private(set) var activeChatID: String?
    private(set) var historyError: String?
    private(set) var isUpdatingHistory = false
    private(set) var status = "Bereit"
    var errorMessage: String?

    @ObservationIgnored private var transcript = TerminalScreen()
    @ObservationIgnored private var terminalColumns = 120
    @ObservationIgnored private var terminalRows = 40
    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var master: Int32 = -1
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var pendingInput = Data()
    @ObservationIgnored private var restartRequested: (continuing: Bool, resuming: String?)?
    @ObservationIgnored private var stopDeadline: ContinuousClock.Instant?
    @ObservationIgnored private let documentReader = DocumentReader()
    @ObservationIgnored private let historyStore = SavedChatStore(directory: FileManager.default.homeDirectoryForCurrentUser.appending(path: ".fm/sessions"))
    @ObservationIgnored private var isRefreshingHistory = false
    @ObservationIgnored private var sessionStartedAt = Date.distantPast
    @ObservationIgnored private var stagedImage: TemporaryChatImage?
    @ObservationIgnored private var imageStartingStatus = ""

    func start(continuing: Bool = false, resuming: String? = nil) {
        guard !isUpdatingHistory else { return }
        if let name = resuming, name.isEmpty || name == "." || name == ".." || name.contains("/") || name.contains("\\") || name.contains("\0") {
            errorMessage = "Ungültiger Chatname."
            return
        }
        if isRunning {
            restartRequested = (continuing, resuming)
            stop()
            return
        }
        guard FileManager.default.isExecutableFile(atPath: "/usr/bin/fm") else {
            errorMessage = "Auf diesem Mac fehlt /usr/bin/fm. Die App benötigt macOS 27 mit dem fm-Befehl."
            status = "fm fehlt"
            return
        }

        guard let executable = Bundle.main.executableURL else {
            errorMessage = "Der Pfad der App konnte nicht ermittelt werden."
            return
        }
        let launcher = executable.deletingLastPathComponent().appending(path: "FMTerminalLauncher")
        guard FileManager.default.isExecutableFile(atPath: launcher.path) else {
            errorMessage = "Der Terminal-Launcher fehlt. Bitte die App mit scripts/build-app.sh neu bauen."
            return
        }

        var slave: Int32 = -1
        var descriptor: Int32 = -1
        var size = winsize(ws_row: UInt16(terminalRows), ws_col: UInt16(terminalColumns), ws_xpixel: 0, ws_ypixel: 0)
        guard openpty(&descriptor, &slave, nil, nil, &size) == 0 else {
            showSystemError("Pseudoterminal konnte nicht geöffnet werden")
            return
        }
        // Slave descriptors must not leak beyond the explicitly inherited standard streams.
        guard fcntl(descriptor, F_SETFD, FD_CLOEXEC) != -1,
              fcntl(slave, F_SETFD, FD_CLOEXEC) != -1,
              fcntl(descriptor, F_SETFL, O_NONBLOCK) != -1 else {
            let code = errno
            Darwin.close(descriptor)
            Darwin.close(slave)
            showSystemError("Pseudoterminal konnte nicht konfiguriert werden", code: code)
            return
        }

        let child = Process()
        child.executableURL = launcher
        child.arguments = if let resuming { ["--resume", resuming] } else { continuing ? ["--continue"] : [] }
        child.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        var environment = ProcessInfo.processInfo.environment
        environment["TERM"] = "xterm-256color"
        environment["LC_CTYPE"] = "UTF-8"
        for name in ["NO_COLOR", "CODEX_CI", "CI"] { environment.removeValue(forKey: name) }
        child.environment = environment
        let terminal = FileHandle(fileDescriptor: slave, closeOnDealloc: false)
        child.standardInput = terminal
        child.standardOutput = terminal
        child.standardError = terminal

        do {
            try child.run()
        } catch {
            Darwin.close(descriptor)
            Darwin.close(slave)
            errorMessage = "fm chat konnte nicht gestartet werden: \(error.localizedDescription)"
            status = "Start fehlgeschlagen"
            return
        }
        Darwin.close(slave)
        master = descriptor
        process = child
        transcript = TerminalScreen(columns: terminalColumns, rows: terminalRows)
        output = ""
        styledOutput = NSAttributedString(string: "")
        replies = []
        modelStatus = ""
        canSend = false
        pendingInput.removeAll()
        stopDeadline = nil
        isRunning = true
        status = "fm chat läuft · Lokales Modell"
        activeChatID = resuming ?? (continuing ? savedChats.max(by: { $0.updatedAt < $1.updatedAt })?.id : nil)
        sessionStartedAt = .now
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, self.isRunning else { return }
                guard self.poll() else { return }
                do { try await Task.sleep(for: .milliseconds(25)) }
                catch { return }
            }
        }
    }

    @discardableResult
    func send(_ text: String) -> Bool {
        guard isRunning, canSend, !isLoadingDocument, !isUpdatingHistory, stopDeadline == nil else { return false }
        let message = document?.prompt(with: text) ?? text
        if document?.isImage == true, !transcript.usesBracketedPaste {
            errorMessage = "Der laufende Chat unterstützt keine Bildanhänge. Bitte einen neuen Chat starten."
            return false
        }
        removeStagedImage()
        if let document, document.isImage {
            do {
                stagedImage = try TemporaryChatImage(document)
                imageStartingStatus = modelStatus
            } catch {
                errorMessage = "Bild konnte nicht übergeben werden: \(error.localizedDescription)"
                return false
            }
        }
        // Paste the file path separately: fm registers it as an image, then appends the user's text.
        guard let data = TerminalInput.encode(message, imagePath: stagedImage?.url.path, bracketedPaste: transcript.usesBracketedPaste) else { return false }
        guard pendingInput.count + data.count <= 65_536 else {
            removeStagedImage()
            errorMessage = "Die Eingabe ist zu lang. Bitte auf höchstens 64 KB kürzen."
            return false
        }
        pendingInput.append(data)
        document = nil
        canSend = false
        flushInput()
        return true
    }

    func attachDocument(_ url: URL) async {
        guard !isLoadingDocument else { return }
        isLoadingDocument = true
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
            isLoadingDocument = false
        }
        do { document = try await documentReader.read(url) }
        catch { errorMessage = "Datei konnte nicht angehängt werden: \(error.localizedDescription)" }
    }

    func removeDocument() {
        document = nil
    }

    func interrupt() {
        guard let process, process.isRunning else { return }
        if Darwin.kill(process.processIdentifier, SIGINT) != 0 {
            showSystemError("fm konnte nicht unterbrochen werden")
        }
    }

    func stop() {
        guard let process, process.isRunning else { return }
        process.terminate()
        canSend = false
        stopDeadline = .now.advanced(by: .seconds(1))
        status = "Chat wird beendet …"
    }

    func shutdown() {
        restartRequested = nil
        pollingTask?.cancel()
        pollingTask = nil
        if let process, process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
        closeTerminal()
    }

    func clearOutput() {
        transcript.clearDisplay()
        updateOutput()
    }

    func copyOutput() {
        _ = copyReply(output)
    }

    func copyReply(_ text: String) -> Bool {
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(text, forType: .string) else {
            errorMessage = "Die Antwort konnte nicht in die Zwischenablage kopiert werden."
            return false
        }
        return true
    }

    func exportOutput() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Foundation-Chat.txt"
        panel.allowedContentTypes = [.plainText]
        panel.begin { [weak self] result in
            guard result == .OK, let url = panel.url else { return }
            do { try self?.output.write(to: url, atomically: true, encoding: .utf8) }
            catch { self?.errorMessage = "Export fehlgeschlagen: \(error.localizedDescription)" }
        }
    }

    private func poll() -> Bool {
        guard let process else { return false }
        readOutput()
        flushInput()
        if let stopDeadline, .now >= stopDeadline, process.isRunning {
            Darwin.kill(process.processIdentifier, SIGKILL)
            self.stopDeadline = nil
        }
        if !process.isRunning {
            readOutput()
            transcript.finish()
            updateOutput()
            let code = process.terminationStatus
            status = code == 0 ? "Chat beendet" : "Chat beendet · Status \(code)"
            closeTerminal()
            pollingTask = nil
            if let request = restartRequested {
                restartRequested = nil
                start(continuing: request.continuing, resuming: request.resuming)
            }
            return false
        }
        return true
    }

    private func readOutput() {
        guard master >= 0 else { return }
        var bytes = [UInt8](repeating: 0, count: 16_384)
        var received = false
        // Bound each pass so a noisy child cannot monopolize the UI thread.
        for _ in 0..<8 {
            let count = Darwin.read(master, &bytes, bytes.count)
            if count > 0 {
                transcript.append(Data(bytes.prefix(count)))
                received = true
            } else {
                if count < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EIO && errno != EINTR {
                    showSystemError("Terminalausgabe konnte nicht gelesen werden")
                    stop()
                }
                break
            }
        }
        if received {
            pendingInput.append(transcript.takeReplies())
            updateOutput()
            canSend = transcript.isReady && stopDeadline == nil
            if canSend, stagedImage != nil, modelStatus != imageStartingStatus { removeStagedImage() }
        }
    }

    private func flushInput() {
        guard master >= 0, !pendingInput.isEmpty else { return }
        let count = pendingInput.withUnsafeBytes { bytes in
            Darwin.write(master, bytes.baseAddress, bytes.count)
        }
        if count > 0 { pendingInput.removeFirst(count) }
        else if count < 0 && errno != EAGAIN && errno != EWOULDBLOCK && errno != EINTR {
            showSystemError("Eingabe konnte nicht an fm übergeben werden")
            pendingInput.removeAll()
            stop()
        }
    }

    private func closeTerminal() {
        if master >= 0 { Darwin.close(master) }
        master = -1
        process = nil
        isRunning = false
        canSend = false
        pendingInput.removeAll()
        stopDeadline = nil
        removeStagedImage()
    }

    private func removeStagedImage() {
        stagedImage?.remove()
        stagedImage = nil
        imageStartingStatus = ""
    }

    func setTerminalSize(columns: Int, rows: Int) {
        let columns = max(20, min(300, columns))
        let rows = max(10, min(150, rows))
        guard columns != terminalColumns || rows != terminalRows else { return }
        terminalColumns = columns
        terminalRows = rows
        transcript.resize(columns: columns, rows: rows)
        guard master >= 0 else { return }
        canSend = false
        var size = winsize(ws_row: UInt16(rows), ws_col: UInt16(columns), ws_xpixel: 0, ws_ypixel: 0)
        if ioctl(master, TIOCSWINSZ, &size) == -1 {
            showSystemError("Terminalgröße konnte nicht angepasst werden")
        }
    }

    private func updateOutput() {
        let lines = transcript.displayLines
        output = lines.map { $0.map(\.text).joined() }.joined(separator: "\n")
        styledOutput = TerminalTextRenderer.render(lines)
        replies = TerminalReplies.extract(from: lines, lastReplyComplete: transcript.isReady || !isRunning)
        modelStatus = transcript.statusText
    }

    func togglePin(_ chat: SavedChat) async {
        guard !isUpdatingHistory else { return }
        isUpdatingHistory = true
        do { try await historyStore.setPinned(!chat.isPinned, id: chat.id) }
        catch { errorMessage = "Anheftung konnte nicht geändert werden: \(error.localizedDescription)" }
        isUpdatingHistory = false
        await refreshHistory()
    }

    func deleteChats(_ ids: Set<String>) async -> Set<String> {
        guard !ids.isEmpty, !isUpdatingHistory, !(isRunning && !canSend) else { return [] }
        isUpdatingHistory = true
        let deletingActiveChat = activeChatID.map(ids.contains) ?? false
        // Stop fm before moving its active file so autosave cannot recreate a deleted chat.
        if deletingActiveChat {
            restartRequested = nil
            stop()
            while isRunning {
                do { try await Task.sleep(for: .milliseconds(25)) }
                catch {
                    isUpdatingHistory = false
                    return []
                }
            }
        }
        var deletedIDs: Set<String> = []
        do {
            let result = try await historyStore.delete(ids: ids)
            deletedIDs = result.deletedIDs
            if !result.warnings.isEmpty { errorMessage = "Chats konnten nicht vollständig gelöscht werden:\n" + result.warnings.joined(separator: "\n") }
        } catch { errorMessage = "Chats konnten nicht gelöscht werden: \(error.localizedDescription)" }
        isUpdatingHistory = false
        if let activeChatID, deletedIDs.contains(activeChatID) {
            self.activeChatID = nil
            start()
        } else if deletingActiveChat, let activeChatID {
            start(resuming: activeChatID)
        }
        await refreshHistory()
        return deletedIDs
    }

    func refreshHistory() async {
        guard !isRefreshingHistory, !isUpdatingHistory else { return }
        isRefreshingHistory = true
        defer { isRefreshingHistory = false }
        do {
            let catalog = try await historyStore.read()
            if savedChats != catalog.chats { savedChats = catalog.chats }
            historyError = catalog.warnings.isEmpty ? nil : catalog.warnings.joined(separator: "\n")
            if activeChatID == nil, isRunning, modelStatus.contains("turn"),
               let latest = savedChats.max(by: { $0.updatedAt < $1.updatedAt }), latest.updatedAt >= sessionStartedAt {
                activeChatID = latest.id
            }
        } catch { historyError = "Chats konnten nicht geladen werden: \(error.localizedDescription)" }
    }

    private func showSystemError(_ message: String, code: Int32 = errno) {
        errorMessage = "\(message): \(String(cString: strerror(code)))"
    }
}
