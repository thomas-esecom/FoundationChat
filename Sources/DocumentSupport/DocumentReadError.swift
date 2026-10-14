import Foundation

public enum DocumentReadError: LocalizedError, Equatable {
    case unsupportedFormat, fileTooLarge, invalidPDF, lockedPDF, noText, invalidUTF8, textTooLarge

    public var errorDescription: String? {
        switch self {
        case .unsupportedFormat: "Bitte ein PDF oder eine Textdatei auswählen."
        case .fileTooLarge: "Die Datei ist größer als 10 MB. Bitte ein kleineres Dokument auswählen."
        case .invalidPDF: "Die Datei konnte nicht als PDF geöffnet werden."
        case .lockedPDF: "Das PDF ist passwortgeschützt. Bitte zuerst eine entsperrte Kopie erstellen."
        case .noText: "Das Dokument enthält keinen auslesbaren Text. Gescannte PDFs benötigen eine Texterkennung (OCR)."
        case .invalidUTF8: "Die Textdatei ist nicht als UTF-8 gespeichert. Bitte zuerst in UTF-8 umwandeln."
        case .textTooLarge: "Der Dokumenttext ist für eine einzelne Nachricht zu lang (maximal 48 KB). Bitte einen kleineren Auszug auswählen."
        }
    }
}
