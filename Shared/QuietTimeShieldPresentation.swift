import Foundation

/// The ritual role carried across the App Group into the ManagedSettings
/// extension. Older snapshots did not have this field and are primary runs.
enum QuietTimeShieldRole: String, Codable, Equatable, Hashable {
    case primaryWindDown
    case additionalQuiet
    case screenFreeMorning
}

enum QuietTimeShieldCueGroup: String, Codable, CaseIterable, Equatable, Hashable {
    case additionalQuiet
    case windDown
    case overnight
    case morningQuiet
}

enum QuietTimeShieldPresentationStorage {
    static let appGroupIdentifier = "group.com.ngawangchime.countingsheep"
    static let scheduleKey = "ollie.screenTime.shieldSchedule"
    static let briefAccessStateKey = "ollie.screenTime.briefAccessState"
    static let purposeCueKey = "ollie.screenTime.purposeCue"
}

/// A bounded local prompt used at the shield intervention point. Free text is
/// intentionally excluded from App Group storage and social/impact contracts.
enum QuietPurposeCue: String, Codable, CaseIterable, Equatable {
    case prepareForSleep
    case read
    case focusOnWork
    case somethingOffline
    case somethingElse

    /// Short copy for the in-app active session. Shield copy remains a little
    /// more descriptive because it is shown at the intervention point.
    var appFacingTitle: String {
        switch self {
        case .prepareForSleep: return "Rest"
        case .read: return "Reading"
        case .focusOnWork: return "Work"
        case .somethingOffline: return "Time offline"
        case .somethingElse: return "Something else"
        }
    }

    var shieldText: String {
        switch self {
        case .prepareForSleep: return "Prepare for sleep"
        case .read: return "Read"
        case .focusOnWork: return "Focus on work"
        case .somethingOffline: return "Something offline"
        case .somethingElse: return "Something else"
        }
    }
}

struct QuietPurposeCueState: Codable, Equatable {
    var occurrenceID: UUID
    var revision: Int
    var epoch: Int
    var cue: QuietPurposeCue

    static func load(from defaults: UserDefaults) -> Self? {
        guard let data = defaults.data(forKey: QuietTimeShieldPresentationStorage.purposeCueKey) else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    static func load(
        matching occurrenceID: UUID,
        revision: Int,
        epoch: Int,
        from defaults: UserDefaults
    ) -> Self? {
        guard let state = load(from: defaults),
              state.occurrenceID == occurrenceID,
              state.revision == revision,
              state.epoch == epoch else {
            return nil
        }
        return state
    }

    static func save(_ value: Self, to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: QuietTimeShieldPresentationStorage.purposeCueKey)
    }

    static func clear(from defaults: UserDefaults) {
        defaults.removeObject(forKey: QuietTimeShieldPresentationStorage.purposeCueKey)
    }

    static func clear(
        occurrenceID: UUID,
        revision: Int,
        epoch: Int,
        from defaults: UserDefaults
    ) {
        guard let current = load(from: defaults),
              current.occurrenceID == occurrenceID,
              current.revision == revision,
              current.epoch == epoch else { return }
        defaults.removeObject(forKey: QuietTimeShieldPresentationStorage.purposeCueKey)
    }
}

/// A run-scoped summary shared by the shield extension and the active-run UI.
/// The extension cannot read FocusRun, so it derives this only from the App
/// Group brief-access ledger.
struct QuietTimeBriefAccessTrackerSummary: Codable, Equatable {
    private static let legacyMinutesPerPause = 5
    let pauseCount: Int
    let allottedMinutes: Int

    init(pauseCount: Int = 0, allottedMinutes: Int = 0) {
        self.pauseCount = max(0, pauseCount)
        self.allottedMinutes = max(0, allottedMinutes)
    }

    var subtitle: String {
        pauseCount > 0
            ? "\(pauseCount) pause\(pauseCount == 1 ? "" : "s") · \(allottedMinutes) min allotted"
            : "No pauses yet"
    }

    struct Use: Codable, Equatable {
        let requestedAt: Date
        let expiresAt: Date
    }

    static func make(
        stateRunID: UUID?,
        successfulUseCount: Int,
        successfulUses: [Use],
        runID: UUID,
        fallbackUseCount: Int = 0
    ) -> Self {
        let fallbackCount = max(0, fallbackUseCount)
        guard stateRunID == runID else {
            return Self(
                pauseCount: fallbackCount,
                allottedMinutes: fallbackCount * legacyMinutesPerPause
            )
        }

        let count = max(fallbackCount, successfulUseCount, successfulUses.count)
        let durationSeconds = successfulUses.reduce(0.0) { total, use in
            total + max(0, use.expiresAt.timeIntervalSince(use.requestedAt))
        }
        let missingCount = max(0, count - successfulUses.count)
        let totalSeconds = durationSeconds + Double(missingCount * legacyMinutesPerPause * 60)
        let minutes = totalSeconds > 0
            ? Int(ceil(totalSeconds / 60))
            : 0
        return Self(pauseCount: count, allottedMinutes: minutes)
    }

    static func load(
        for runID: UUID?,
        from defaults: UserDefaults,
        fallbackUseCount: Int = 0
    ) -> Self {
        guard let runID,
              let data = defaults.data(forKey: QuietTimeShieldPresentationStorage.briefAccessStateKey),
              let state = try? JSONDecoder().decode(StoredState.self, from: data) else {
            return Self(
                pauseCount: fallbackUseCount,
                allottedMinutes: max(0, fallbackUseCount) * legacyMinutesPerPause
            )
        }
        return make(
            stateRunID: state.runID,
            successfulUseCount: state.successfulUseCount,
            successfulUses: state.successfulUses,
            runID: runID,
            fallbackUseCount: fallbackUseCount
        )
    }

    private struct StoredState: Codable {
        let runID: UUID
        let successfulUseCount: Int
        let successfulUses: [Use]

        private enum CodingKeys: String, CodingKey {
            case runID, successfulUseCount, successfulUses
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            runID = try container.decode(UUID.self, forKey: .runID)
            successfulUseCount = max(
                0,
                try container.decodeIfPresent(Int.self, forKey: .successfulUseCount) ?? 0
            )
            successfulUses = try container.decodeIfPresent([Use].self, forKey: .successfulUses) ?? []
        }
    }
}

/// The small Codable view of the schedule used by Shield Configuration. Its
/// keys intentionally mirror QuietTimeShieldScheduleSnapshot so the extension
/// can read the App Group contract without importing the app's domain graph.
struct QuietTimeShieldPresentationSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 4

    var schemaVersion: Int
    var runID: UUID
    var revision: Int
    var registryRevision: Int
    var registryEpoch: Int
    var role: QuietTimeShieldRole
    var protectedSessionInterval: DateInterval?
    var windDownInterval: DateInterval?
    var morningQuietInterval: DateInterval
    var updatedAt: Date
    var repeatsDaily: Bool

    init(
        schemaVersion: Int = currentSchemaVersion,
        runID: UUID,
        revision: Int,
        registryRevision: Int = 1,
        registryEpoch: Int = 1,
        role: QuietTimeShieldRole = .primaryWindDown,
        protectedSessionInterval: DateInterval? = nil,
        windDownInterval: DateInterval?,
        morningQuietInterval: DateInterval,
        updatedAt: Date,
        repeatsDaily: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.revision = max(1, revision)
        self.registryRevision = max(1, registryRevision)
        self.registryEpoch = max(1, registryEpoch)
        self.role = role
        self.protectedSessionInterval = protectedSessionInterval
        self.windDownInterval = windDownInterval
        self.morningQuietInterval = morningQuietInterval
        self.updatedAt = updatedAt
        self.repeatsDaily = repeatsDaily
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, runID, revision, registryRevision, registryEpoch, role
        case protectedSessionInterval, windDownInterval, morningQuietInterval
        case updatedAt, repeatsDaily
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? Self.currentSchemaVersion
        schemaVersion = max(storedSchemaVersion, Self.currentSchemaVersion)
        runID = try container.decode(UUID.self, forKey: .runID)
        revision = max(1, try container.decodeIfPresent(Int.self, forKey: .revision) ?? 1)
        registryRevision = max(1, try container.decodeIfPresent(Int.self, forKey: .registryRevision) ?? 1)
        registryEpoch = max(1, try container.decodeIfPresent(Int.self, forKey: .registryEpoch) ?? 1)
        role = try container.decodeIfPresent(QuietTimeShieldRole.self, forKey: .role)
            ?? .primaryWindDown
        protectedSessionInterval = try container.decodeIfPresent(
            DateInterval.self,
            forKey: .protectedSessionInterval
        )
        windDownInterval = try container.decodeIfPresent(DateInterval.self, forKey: .windDownInterval)
        morningQuietInterval = try container.decode(DateInterval.self, forKey: .morningQuietInterval)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        repeatsDaily = try container.decodeIfPresent(Bool.self, forKey: .repeatsDaily) ?? false
    }

    static func decode(_ data: Data?) -> Self? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }

    static func load(from defaults: UserDefaults) -> Self? {
        decode(defaults.data(forKey: QuietTimeShieldPresentationStorage.scheduleKey))
    }

    /// The protected session is the source of truth for the end displayed on
    /// the shield. Bookend intervals are intentionally not used as a fallback
    /// because they can end before the actual app-limit period.
    var protectedEndDate: Date? {
        protectedSessionInterval?.end
    }

    func cueGroup(at date: Date) -> QuietTimeShieldCueGroup {
        switch role {
        case .additionalQuiet:
            return .additionalQuiet
        case .screenFreeMorning:
            return .morningQuiet
        case .primaryWindDown:
            break
        }
        if contains(date, in: windDownInterval) { return .windDown }
        if contains(date, in: morningQuietInterval) { return .morningQuiet }
        if contains(date, in: protectedSessionInterval) { return .overnight }
        return .windDown
    }

    private func contains(_ date: Date, in interval: DateInterval?) -> Bool {
        guard let interval else { return false }
        if repeatsDaily {
            let calendar = Calendar.current
            let start = calendar.dateComponents([.hour, .minute, .second], from: interval.start)
            let end = calendar.dateComponents([.hour, .minute, .second], from: interval.end)
            let current = calendar.dateComponents([.hour, .minute, .second], from: date)
            let startSeconds = (start.hour ?? 0) * 3600 + (start.minute ?? 0) * 60 + (start.second ?? 0)
            let endSeconds = (end.hour ?? 0) * 3600 + (end.minute ?? 0) * 60 + (end.second ?? 0)
            let currentSeconds = (current.hour ?? 0) * 3600 + (current.minute ?? 0) * 60 + (current.second ?? 0)
            if endSeconds > startSeconds {
                return currentSeconds >= startSeconds && currentSeconds < endSeconds
            }
            return currentSeconds >= startSeconds || currentSeconds < endSeconds
        }
        return date >= interval.start && date < interval.end
    }
}

/// Finite, first-party shield cues. Selection is stable for a run and phase,
/// so a shield refresh does not produce an unpredictable new message.
enum ShieldCueCatalog {
    static let additionalQuiet = [
        "The next few minutes do not need a screen.",
        "Leave the scroll here. Let your attention land somewhere else.",
        "One less check can make a little more room."
    ]

    static let windDown = [
        "Set the phone down. Let the room grow quieter.",
        "Choose something gentle and offline for the next few minutes."
    ]

    static let overnight = [
        "Your phone is tucked away. There is nothing else to do here."
    ]

    static let morningQuiet = [
        "Let the morning begin before the phone does.",
        "Open the curtains before opening another app."
    ]

    static func cues(for group: QuietTimeShieldCueGroup) -> [String] {
        switch group {
        case .additionalQuiet: return additionalQuiet
        case .windDown: return windDown
        case .overnight: return overnight
        case .morningQuiet: return morningQuiet
        }
    }

    static func cue(
        for group: QuietTimeShieldCueGroup,
        runID: UUID?,
        date: Date,
        calendar: Calendar = .current
    ) -> String {
        let candidates = cues(for: group)
        guard !candidates.isEmpty else { return "The next few minutes do not need a screen." }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        let seed = "\(runID?.uuidString ?? "fallback")|\(group.rawValue)|\(day)"
        return candidates[stableIndex(for: seed, count: candidates.count)]
    }

    private static func stableIndex(for seed: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % UInt64(count))
    }
}
