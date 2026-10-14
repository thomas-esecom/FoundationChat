import DocumentSupport
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var session: ChatSession
    @State private var prompt = ""
    @State private var showingDocumentPicker = false
    @State private var inputFocusRequest = 0
    @State private var inputHeight: CGFloat = 24

    private static let documentTypes: [UTType] = [.pdf, .jpeg, .png] + DocumentReader.textExtensions.compactMap {
        UTType(filenameExtension: $0)
    }

    var body: some View {
        VStack(spacing: 0) {
            TerminalOutputView(text: session.styledOutput, replies: session.replies,
                               onCopy: session.copyReply, onResize: session.setTerminalSize)
            Divider()

            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Button("Datei anhängen", systemImage: "paperclip") { showingDocumentPicker = true }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .disabled(session.isLoadingDocument)
                        .help("JPG, PNG, PDF oder Textdatei anhängen")
                    if session.isLoadingDocument {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Datei wird gelesen")
                    } else if let document = session.document {
                        HStack(spacing: 6) {
                            Label(document.name, systemImage: document.isImage ? "photo" : "doc.text")
                                .lineLimit(1)
                                .help(document.isImage ? "Bild mit der nächsten Nachricht lokal analysieren lassen" : "Dokumenttext lokal mit der nächsten Nachricht mitsenden")
                            Button("Anhang entfernen", systemImage: "xmark", action: session.removeDocument)
                                .labelStyle(.iconOnly)
                                .buttonStyle(.plain)
                        }
                        .font(.callout)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: .capsule)
                        .frame(maxWidth: 200)
                    }
                    PromptInputView(text: $prompt, isEnabled: session.isRunning, focusRequest: inputFocusRequest,
                        onHeightChange: { inputHeight = $0 }, onSubmit: sendPrompt)
                        .frame(height: inputHeight)
                    Button("Senden", systemImage: "arrow.up", action: sendPrompt)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderedProminent)
                        .tint(Color(white: 0.82))
                        .foregroundStyle(Color(white: 0.18))
                        .disabled(!session.canSend || session.isLoadingDocument || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .help("Nachricht senden (Return)")
                }
                .frame(minHeight: 28)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(red: 0.145, green: 0.155, blue: 0.165))

                HStack(alignment: .lastTextBaseline) {
                    Text(session.modelStatus.isEmpty ? "Warte auf Modellstatus …" : session.modelStatus)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .textSelection(.enabled)
                        .accessibilityLabel("Modell- und Tokenstatus: \(session.modelStatus)")
                    Spacer(minLength: 12)
                    Text(session.status)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .layoutPriority(1)
                        .help(session.status)
                }
                .padding(.horizontal, 12)
                .padding(.top, 5)
                .padding(.bottom, 5)
            }
            .background(Color(red: 0.16, green: 0.17, blue: 0.18))
        }
        .frame(minWidth: 620, minHeight: 420)
        .toolbar {
            ToolbarItemGroup {
                Button("Neuer Chat", systemImage: "plus") { session.start() }
                    .help("Eine neue fm-chat-Sitzung starten")
                Button("Fortsetzen", systemImage: "clock.arrow.circlepath") { session.start(continuing: true) }
                    .help("Die letzte von fm gespeicherte Sitzung fortsetzen")
                Button("Beenden", systemImage: "stop.fill", action: session.stop)
                    .disabled(!session.isRunning)
                Menu("Ausgabe", systemImage: "ellipsis.circle") {
                    Button("Ausgabe kopieren", systemImage: "doc.on.doc", action: session.copyOutput)
                    Button("Als Text exportieren …", systemImage: "square.and.arrow.up", action: session.exportOutput)
                    Divider()
                    Button("Anzeige leeren", systemImage: "clear", action: session.clearOutput)
                }
            }
        }
        .toolbarBackground(Color(red: 0.20, green: 0.21, blue: 0.23), for: .windowToolbar)
        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        .fileImporter(isPresented: $showingDocumentPicker, allowedContentTypes: Self.documentTypes) { result in
            switch result {
            case .success(let url): Task { await session.attachDocument(url) }
            case .failure(let error): session.errorMessage = "Dateiauswahl fehlgeschlagen: \(error.localizedDescription)"
            }
        }
        .task {
            if !session.isRunning { session.start() }
            inputFocusRequest += 1
        }
        .onChange(of: session.canSend) {
            if session.canSend { inputFocusRequest += 1 }
        }
        .alert("FoundationChat", isPresented: Binding(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { session.errorMessage = nil }
        } message: {
            Text(session.errorMessage ?? "")
        }
    }

    private func sendPrompt() {
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if session.send(prompt) { prompt = "" }
        inputFocusRequest += 1
    }
}
