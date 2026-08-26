import Foundation

enum PhoneBedTagPurpose: String, Codable, CaseIterable, Hashable {
    case windDown
    case phoneAway

    var displayName: String {
        switch self {
        case .windDown: return "Wind Down"
        case .phoneAway: return "Phone Away"
        }
    }
}

enum PhoneBedTagRole: String, Codable, CaseIterable, Hashable {
    case primary
    case backup

    var displayName: String {
        switch self {
        case .primary: return "Primary"
        case .backup: return "Backup"
        }
    }
}

struct NamedPhoneBedTagRegistration: Codable, Equatable, Identifiable {
    static let maximumNameLength = 40
    static let defaultName = "Wind Down tag"
    static let allPurposes = Set(PhoneBedTagPurpose.allCases)

    let id: UUID
    var name: String
    let tokenDigest: String
    let registeredAt: Date
    var lastVerifiedAt: Date?
    var role: PhoneBedTagRole
    var purposes: Set<PhoneBedTagPurpose>

    init(
        id: UUID = UUID(),
        name: String,
        tokenDigest: String,
        registeredAt: Date,
        lastVerifiedAt: Date? = nil,
        role: PhoneBedTagRole,
        purposes: Set<PhoneBedTagPurpose>
    ) {
        self.id = id
        self.name = Self.normalizedName(name)
        self.tokenDigest = tokenDigest.trimmingCharacters(in: .whitespacesAndNewlines)
        self.registeredAt = registeredAt
        self.lastVerifiedAt = lastVerifiedAt
        self.role = role
        self.purposes = purposes.isEmpty ? Self.allPurposes : purposes
    }

    var suggestedLabel: String {
        "Counting Sheep — \(name)"
    }

    var purposesDescription: String {
        let ordered = PhoneBedTagPurpose.allCases.filter(purposes.contains)
        if ordered.count == PhoneBedTagPurpose.allCases.count {
            return "Wind Down and Phone Away"
        }
        return ordered.map(\.displayName).joined(separator: " and ")
    }

    func supports(_ purpose: PhoneBedTagPurpose) -> Bool {
        purposes.contains(purpose)
    }

    func matches(scannedDigest: String, purpose: PhoneBedTagPurpose) -> Bool {
        tokenDigest == scannedDigest && supports(purpose)
    }

    static func normalizedName(_ proposedName: String) -> String {
        let trimmed = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = String(trimmed.prefix(maximumNameLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return limited.isEmpty ? defaultName : limited
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, tokenDigest, registeredAt, lastVerifiedAt, role, purposes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            name: try container.decode(String.self, forKey: .name),
            tokenDigest: try container.decode(String.self, forKey: .tokenDigest),
            registeredAt: try container.decode(Date.self, forKey: .registeredAt),
            lastVerifiedAt: try container.decodeIfPresent(Date.self, forKey: .lastVerifiedAt),
            role: try container.decode(PhoneBedTagRole.self, forKey: .role),
            purposes: Set(try container.decode([PhoneBedTagPurpose].self, forKey: .purposes))
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(tokenDigest, forKey: .tokenDigest)
        try container.encode(registeredAt, forKey: .registeredAt)
        try container.encodeIfPresent(lastVerifiedAt, forKey: .lastVerifiedAt)
        try container.encode(role, forKey: .role)
        try container.encode(
            PhoneBedTagPurpose.allCases.filter(purposes.contains),
            forKey: .purposes
        )
    }
}

struct PhoneBedTagLibrary: Codable, Equatable {
    static let currentSchemaVersion = 2
    static let maximumTagCount = 2

    var schemaVersion: Int
    private(set) var tags: [NamedPhoneBedTagRegistration]
    /// Digests are retained locally after replacement so an old physical tag
    /// cannot be mistaken for a new blank credential. Raw NFC tokens never
    /// leave the tag and are not persisted here.
    private(set) var previouslyPairedTokenDigests: Set<String>

    init(
        schemaVersion: Int = currentSchemaVersion,
        tags: [NamedPhoneBedTagRegistration] = [],
        previouslyPairedTokenDigests: Set<String> = []
    ) {
        self.schemaVersion = schemaVersion
        self.tags = Self.normalized(tags)
        let activeDigests = Set(self.tags.map(\.tokenDigest))
        self.previouslyPairedTokenDigests = Set(
            previouslyPairedTokenDigests
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !activeDigests.contains($0) }
        )
    }

    var primary: NamedPhoneBedTagRegistration? {
        tags.first { $0.role == .primary }
    }

    var backup: NamedPhoneBedTagRegistration? {
        tags.first { $0.role == .backup }
    }

    func tag(for role: PhoneBedTagRole) -> NamedPhoneBedTagRegistration? {
        tags.first { $0.role == role }
    }

    func tag(matching digest: String) -> NamedPhoneBedTagRegistration? {
        tags.first { $0.tokenDigest == digest }
    }

    func wasPreviouslyPaired(digest: String) -> Bool {
        previouslyPairedTokenDigests.contains(
            digest.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    func authenticatingTag(
        digest: String,
        purpose: PhoneBedTagPurpose
    ) -> NamedPhoneBedTagRegistration? {
        tags.first { $0.matches(scannedDigest: digest, purpose: purpose) }
    }

    func hasTag(for purpose: PhoneBedTagPurpose) -> Bool {
        tags.contains { $0.supports(purpose) }
    }

    mutating func replace(
        role: PhoneBedTagRole,
        with registration: NamedPhoneBedTagRegistration
    ) {
        if let oldRegistration = tags.first(where: { $0.role == role }),
           oldRegistration.tokenDigest != registration.tokenDigest {
            previouslyPairedTokenDigests.insert(oldRegistration.tokenDigest)
        }
        var replacement = registration
        replacement.role = role
        tags.removeAll { $0.role == role || $0.tokenDigest == replacement.tokenDigest }
        tags.append(replacement)
        tags = Self.normalized(tags)
        previouslyPairedTokenDigests.subtract(tags.map(\.tokenDigest))
    }

    /// Retains a credential discovered during recovery so a later scan cannot
    /// silently turn an old physical credential back into an active tag.
    mutating func retireCredential(_ digest: String) {
        let normalized = digest.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              !tags.contains(where: { $0.tokenDigest == normalized }) else { return }
        previouslyPairedTokenDigests.insert(normalized)
    }

    mutating func rename(id: UUID, to name: String) {
        guard let index = tags.firstIndex(where: { $0.id == id }) else { return }
        tags[index].name = NamedPhoneBedTagRegistration.normalizedName(name)
    }

    mutating func changePurposes(
        id: UUID,
        to purposes: Set<PhoneBedTagPurpose>
    ) {
        guard !purposes.isEmpty,
              let index = tags.firstIndex(where: { $0.id == id }) else { return }
        tags[index].purposes = purposes
    }

    @discardableResult
    mutating func markVerified(
        digest: String,
        purpose: PhoneBedTagPurpose? = nil,
        at date: Date
    ) -> NamedPhoneBedTagRegistration? {
        guard let index = tags.firstIndex(where: {
            guard $0.tokenDigest == digest else { return false }
            return purpose.map($0.supports) ?? true
        }) else { return nil }
        tags[index].lastVerifiedAt = date
        return tags[index]
    }

    mutating func forget(id: UUID) {
        tags.removeAll { $0.id == id }
        tags = Self.normalized(tags)
    }

    static func migrated(
        from legacyRegistration: PhoneBedTagRegistration?,
        legacyDigest: String?
    ) -> PhoneBedTagLibrary? {
        let registrationDigest = legacyRegistration?.tokenDigest
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let digest = registrationDigest.flatMap({ $0.isEmpty ? nil : $0 }) ?? legacyDigest,
              !digest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let registration = NamedPhoneBedTagRegistration(
            // The legacy ID was also the raw NDEF credential. A fresh local ID
            // breaks that coupling while the digest preserves authentication.
            id: UUID(),
            name: NamedPhoneBedTagRegistration.defaultName,
            tokenDigest: digest,
            registeredAt: legacyRegistration?.registeredAt ?? Date(),
            lastVerifiedAt: legacyRegistration?.lastVerifiedAt,
            role: .primary,
            purposes: NamedPhoneBedTagRegistration.allPurposes
        )
        return PhoneBedTagLibrary(tags: [registration])
    }

    private static func normalized(
        _ registrations: [NamedPhoneBedTagRegistration]
    ) -> [NamedPhoneBedTagRegistration] {
        let valid = registrations.filter { !$0.tokenDigest.isEmpty }
        let sorted = valid.sorted {
            if $0.role != $1.role { return $0.role == .primary }
            if $0.registeredAt != $1.registeredAt { return $0.registeredAt < $1.registeredAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        var seenDigests = Set<String>()
        var unique = sorted.filter { seenDigests.insert($0.tokenDigest).inserted }
        guard !unique.isEmpty else { return [] }

        let primaryIndex = unique.firstIndex { $0.role == .primary } ?? unique.startIndex
        var primary = unique.remove(at: primaryIndex)
        primary.role = .primary
        var result = [primary]
        if var backup = unique.first {
            backup.role = .backup
            result.append(backup)
        }
        return Array(result.prefix(maximumTagCount))
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, tags, previouslyPairedTokenDigests
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? Self.currentSchemaVersion
        tags = Self.normalized(
            try container.decodeIfPresent(
                [NamedPhoneBedTagRegistration].self,
                forKey: .tags
            ) ?? []
        )
        let activeDigests = Set(tags.map(\.tokenDigest))
        previouslyPairedTokenDigests = Set(
            (try container.decodeIfPresent([String].self, forKey: .previouslyPairedTokenDigests) ?? [])
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty && !activeDigests.contains($0) }
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(Self.normalized(tags), forKey: .tags)
        try container.encode(
            previouslyPairedTokenDigests.sorted(),
            forKey: .previouslyPairedTokenDigests
        )
    }
}

/// Legacy singular registration retained only for decoding and migration.
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
