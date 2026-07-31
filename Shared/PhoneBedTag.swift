import Foundation

struct PhoneBedTagRegistration: Codable, Equatable, Identifiable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    let id: UUID
    let tokenDigest: String
    let registeredAt: Date
    var lastVerifiedAt: Date?

    init(
        schemaVersion: Int = currentSchemaVersion,
        id: UUID,
        tokenDigest: String,
        registeredAt: Date,
        lastVerifiedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.tokenDigest = tokenDigest
        self.registeredAt = registeredAt
        self.lastVerifiedAt = lastVerifiedAt
    }

    func matches(scannedDigest: String) -> Bool {
        tokenDigest == scannedDigest
    }
}
