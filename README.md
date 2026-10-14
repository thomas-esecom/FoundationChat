# FoundationChat

Native macOS-App als Terminaloberfläche für Apples `/usr/bin/fm chat`. SwiftUI-Fenster, auswählbare Terminalausgabe und ein eigenes Eingabefeld. Keine externen Pakete und kein API-Schlüssel.

## Download

[FoundationChat 0.9 herunterladen](https://github.com/thomas-esecom/FoundationChat/releases/download/v0.9/FoundationChat-0.9-macOS-arm64.zip). Das ZIP entpacken und `FoundationChat.app` in den Ordner „Programme“ ziehen. Der Download ist für Macs mit Apple Silicon, macOS 27 und verfügbarem Apple-Intelligence-Modell gedacht. Die App ist ad-hoc signiert und nicht notarisiert; macOS kann beim ersten Öffnen eine Sicherheitsfreigabe verlangen.

## Voraussetzungen

- macOS 27 oder neuer mit `/usr/bin/fm`
- Apple Intelligence und ein verfügbares lokales Modell (`fm available`)
- Zum Bauen: Xcode mit Swift 6.2 oder neuer, passend zum installierten macOS

## Bauen und starten

```bash
bash scripts/build-app.sh
open "dist/FoundationChat.app"
```

Das Swift-Package lässt sich über `Package.swift` in Xcode öffnen. Die fertige App liegt unter `dist/FoundationChat.app`. Sie ist für lokale Nutzung ad-hoc signiert, nicht notarisiert oder für den App Store paketiert.

## Bedienung

- Die Sidebar zeigt die von `fm` unter `~/.fm/sessions/` gespeicherten Chats. Suche filtert Titel und Antwortvorschau; die Auswahl setzt den jeweiligen Chat samt Modellkontext fort. Neu gespeicherte Chats erscheinen automatisch.
- Über „Edit“ lassen sich mehrere Chats auswählen und gemeinsam in den macOS-Papierkorb verschieben. Die Stecknadel heftet Chats oben an; eine feine Linie trennt sie von den übrigen Chats. Beide Gruppen sind nach letzter Änderung absteigend sortiert. Anheftungen werden separat in `~/.fm/sessions/.foundationchat-pins.json` gespeichert.
- Rechts neben jeder abgeschlossenen Antwort steht ein Kopiersymbol. Es kopiert nur diese Antwort als Klartext, einschließlich Codeeinrückung. Fragen, Anhänge und Statusinformationen werden ausgelassen.
- Das App-Icon ist ein eigenes, mit dem integrierten ImageGen-Werkzeug erstelltes Motiv ohne Apple-Logo. Quelle: `Resources/AppIcon.png`; Prompt: `Resources/AppIcon.prompt.txt`. `scripts/build-icon.sh` erzeugt daraus die macOS-Icondatei.

- Dunkle Oberfläche mit abgesetzter Headerleiste und Eingabebereich. Modellstatus links und Prozessstatus rechts im Footer.
- Über die Büroklammer ein PDF mit auslesbarem Text oder eine UTF-8-Textdatei (z. B. TXT, Markdown, CSV oder Quellcode) anhängen. Der Text wird mit der nächsten Nachricht an das lokale Modell übergeben; es wird keine Datei auf einen Server hochgeladen. Der Anhang kann vor dem Senden entfernt werden.
- Maximal 10 MB Dateigröße und 48 KB extrahierter Text. Es wird nichts automatisch gekürzt. Gescannten PDFs fehlt ohne OCR auslesbarer Text; Word-Dateien werden derzeit nicht unterstützt. Der verfügbare Modellkontext (aktuell 8192 Tokens inklusive Gespräch) kann schon vor der Dateigrößengrenze ausgeschöpft sein; die entsprechende `fm`-Fehlermeldung erscheint in der Ausgabe.
- Die App startet `fm chat --model system` automatisch in einem Pseudoterminal. Der mitgelieferte Terminal-Launcher verbindet es als steuerndes Terminal, sodass `fm` seine interaktive Ansicht verwendet.
- Fragen erscheinen grau, Antworten hell, Überschriften farbig und Code abgesetzt. ANSI-Farben, Fett- und Code-Darstellung stammen direkt aus `fm`.
- Unter der Eingabe steht die echte `fm`-Statuszeile: Modell, Gesprächsrunde, Eingabe-/Ausgabetokens und belegter Kontext. Sie aktualisiert sich während der Antwort und wird nicht geschätzt.
- Enter bzw. der Senden-Button übergibt eine Nachricht, Shift-Enter fügt einen Umbruch ein. Die Eingabe bricht automatisch um und wächst bis zu einer Höhe von 160 Punkten; längere Eingaben lassen sich scrollen. `- ` am Zeilenanfang beginnt eine Aufzählung, die Shift-Enter fortsetzt. Ein Umbruch auf einem leeren Listenpunkt beendet die Liste. Dokumentabsätze bleiben durch die interaktive Einfügefunktion von `fm` erhalten.
- **Neuer Chat / ⌘N:** aktuelle Sitzung beenden und eine neue starten.
- **Fortsetzen / ⇧⌘N:** die letzte von `fm` gespeicherte Sitzung mit `--continue` öffnen. Die Speicherung liegt bei `fm` unter `~/.fm/sessions/`.
- **Chat → Unterbrechen / Ctrl+C:** SIGINT an `fm` senden. Je nach Verhalten des CLI kann dies die Sitzung beenden.
- **Beenden:** den laufenden `fm`-Prozess stoppen. Das Schließen der App beendet den Kindprozess ebenfalls.
- **Ausgabe:** kopieren, als UTF-8-Text exportieren oder die Anzeige leeren (⌘K).

Die Ausgabe unterstützt UTF-8, ANSI-Farben, Bildschirmkoordinaten und Scrollback für die interaktive `fm`-Ansicht. Die Terminalgröße folgt der Fenstergröße. Es handelt sich nicht um einen vollständigen VT-Emulator für beliebige Terminalprogramme. Der Scrollback ist auf 2500 Zeilen begrenzt; Exporte enthalten den sichtbaren Chatverlauf als Klartext. Beim Starten oder Fortsetzen wird die Anzeige neu aufgebaut.

Fehler des Modells erscheinen unverändert in der Terminalausgabe. Meldet `fm available` ein verfügbares Modell, kann eine konkrete Anfrage trotzdem fehlschlagen.

## Prüfen

```bash
swift test
```

Tests prüfen UTF-8, ANSI/OSC, Farben, Cursorbewegungen, Statuszeilen, Scrollback, Antwortabgrenzung samt Codeeinrückung, Dokumentextraktion sowie das Lesen und Aktualisieren gespeicherter Chats. Eine aufgezeichnete echte `fm`-Codeantwort dient als Regressionstest für fragmentierte Terminaldaten. Sie ersetzen keinen Live-Test mit dem Apple-Modell.
