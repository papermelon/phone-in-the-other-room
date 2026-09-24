import Foundation

/// Device-only, account-scoped settings and replay journal. Never a Farm payload.
@MainActor
final class CampfireVisibilityStore {
    let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CountingSheep/CampfireVisibility", isDirectory: true)
    }
    func load(owner: UUID) throws -> CampfireVisibilityDocument {
        let file = url(owner)
        for candidate in [file, file.appendingPathExtension("recovery")] {
            guard let data = try? Data(contentsOf: candidate) else { continue }
            // A deliberate newer format is not interrupted data. Falling back
            // to an older enabled audience could undo a newer app's Off choice.
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let version = object["version"] as? Int, version != 1 { throw CocoaError(.fileReadCorruptFile) }
            if let document = try? JSONDecoder().decode(CampfireVisibilityDocument.self, from: data), document.version == 1 { return document }
        }
        guard ![file, file.appendingPathExtension("recovery")].contains(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return CampfireVisibilityDocument()
    }
    func save(_ document: CampfireVisibilityDocument, owner: UUID) throws {
        guard document.commands.count <= 64 else { throw CocoaError(.fileWriteOutOfSpace) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(document)
        let file = url(owner)
        try data.write(to: file, options: .atomic)
        try data.write(to: file.appendingPathExtension("recovery"), options: .atomic)
    }
    private func url(_ owner: UUID) -> URL { directory.appendingPathComponent(owner.uuidString.lowercased() + ".json") }
}
