import Foundation

/// Device-only commands, partitioned by immutable account UUID. Replays keep the
/// original epoch/revision and idempotency key, including after a lost response.
@MainActor
final class SharedPastureOutboxService {
    struct Document: Codable {
        var version = 1
        var commands: [SharedPastureCommand] = []
    }
    let directory: URL
    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CountingSheep/PastureOutbox", isDirectory: true)
    }
    func commands(owner: UUID) throws -> [SharedPastureCommand] {
        let file = url(owner)
        for candidate in [file, file.appendingPathExtension("recovery")] {
            if let data = try? Data(contentsOf: candidate),
               let value = try? JSONDecoder().decode(Document.self, from: data), value.version == 1 {
                return value.commands
            }
        }
        if FileManager.default.fileExists(atPath: file.path) || FileManager.default.fileExists(atPath: file.appendingPathExtension("recovery").path) { throw CocoaError(.fileReadCorruptFile) }
        return []
    }
    func enqueue(_ command: SharedPastureCommand, owner: UUID) throws {
        var saved = try commands(owner: owner)
        guard !saved.contains(where: { $0.id == command.id }) else { return }
        if command.command == "setCampfireSharing" {
            // Revocation wins locally before transport; queued starts cannot escape it.
            saved.removeAll { $0.partyID == command.partyID && $0.command == "publishCampfireSession" }
        }
        if command.command == "publishCampfireSession" {
            guard !saved.contains(where: { $0.partyID == command.partyID && $0.command == "setCampfireSharing" }) else { return }
            let sameSource: (SharedPastureCommand) -> Bool = {
                $0.partyID == command.partyID && $0.command == command.command && $0.sourceID == command.sourceID
            }
            guard !saved.contains(where: { sameSource($0) && ($0.revision ?? 0) >= (command.revision ?? 0) }) else { return }
            saved.removeAll(where: sameSource)
        }
        guard saved.count < 64 else { throw CocoaError(.fileWriteOutOfSpace) }
        saved.append(command)
        try write(saved, owner: owner)
    }
    func remove(_ id: String, owner: UUID) throws {
        try write(commands(owner: owner).filter { $0.id != id }, owner: owner)
    }
    struct VisitIndex: Codable {
        var version = 1
        var parties: [UUID: Set<UUID>] = [:]
    }

    func visitIndex(owner: UUID) throws -> [UUID: Set<UUID>] {
        let file = url(owner).appendingPathExtension("visits")
        for candidate in [file, file.appendingPathExtension("recovery")] {
            if let data = try? Data(contentsOf: candidate),
               let value = try? JSONDecoder().decode(VisitIndex.self, from: data), value.version == 1 { return value.parties }
        }
        if [file, file.appendingPathExtension("recovery")].contains(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            throw CocoaError(.fileReadCorruptFile)
        }
        return [:]
    }

    func saveVisitIndex(_ parties: [UUID: Set<UUID>], owner: UUID) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(VisitIndex(parties: parties))
        let file = url(owner).appendingPathExtension("visits")
        try data.write(to: file, options: .atomic)
        try data.write(to: file.appendingPathExtension("recovery"), options: .atomic)
    }

    private func url(_ owner: UUID) -> URL { directory.appendingPathComponent(owner.uuidString.lowercased() + ".json") }
    private func write(_ commands: [SharedPastureCommand], owner: UUID) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Document(commands: commands))
        let file = url(owner)
        // Refresh both copies after acknowledgement. If interrupted between writes,
        // the original server idempotency key makes recovery replay harmless.
        try data.write(to: file, options: .atomic)
        try data.write(to: file.appendingPathExtension("recovery"), options: .atomic)
    }
}
