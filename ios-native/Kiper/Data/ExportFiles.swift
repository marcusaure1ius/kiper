import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Share-sheet payloads. Written to a temp file with a readable name on demand.
struct JSONExport: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { item in
            SentTransferredFile(try write(item.data, name: "kiper_backup.json"))
        }
    }
}

struct CSVExport: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { item in
            SentTransferredFile(try write(Data(item.text.utf8), name: "kiper_subscriptions.csv"))
        }
    }
}

private func write(_ data: Data, name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    try data.write(to: url, options: .atomic)
    return url
}
