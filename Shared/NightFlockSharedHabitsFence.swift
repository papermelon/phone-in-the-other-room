import Foundation

/// A locally durable boundary for a party action whose server result is not
/// known yet. It prevents the app from showing or sending to that party while
/// preserving the distinction between a local privacy stop and remote proof.
struct NightFlockSharedHabitsPrivacyFence: Codable, Equatable, Identifiable, Sendable {
    enum Action: String, Codable, Equatable, Sendable {
        case leave
        case withdrawHistory
        case dissolveAndLeave
    }

    var id: UUID
    var partyID: UUID
    var action: Action
    var createdAt: Date
    /// A durable destructive intent must reuse one transport key on retries.
    var commandID: UUID?

    init(
        id: UUID = UUID(),
        partyID: UUID,
        action: Action,
        createdAt: Date = Date(),
        commandID: UUID? = UUID()
    ) {
        self.id = id
        self.partyID = partyID
        self.action = action
        self.createdAt = createdAt
        self.commandID = commandID
    }
}

enum NightFlockSharedHabitsFencePolicy {
    enum ArchiveDeletionDisposition: Equatable, Sendable {
        case send
        case preservePendingFence
        case unavailable
    }

    enum PartyExitDisposition: Equatable, Sendable {
        case stageSharedHabitsFence
        case sendLegacyCommand
    }

    /// Legacy fan-out is account-wide, so one unresolved destructive action
    /// pauses every send until membership is reconciled authoritatively.
    static func permitsAnyPublication(
        fences: [NightFlockSharedHabitsPrivacyFence]
    ) -> Bool {
        fences.isEmpty
    }

    static func permitsPartyReadOrPublication(
        partyID: UUID,
        fences: [NightFlockSharedHabitsPrivacyFence]
    ) -> Bool {
        !fences.contains(where: { $0.partyID == partyID })
    }

    static func replacing(
        _ fences: [NightFlockSharedHabitsPrivacyFence],
        with fence: NightFlockSharedHabitsPrivacyFence
    ) -> [NightFlockSharedHabitsPrivacyFence] {
        fences.filter { $0.partyID != fence.partyID } + [fence]
    }

    /// An empty list is authoritative only after a successful canonical list
    /// response. Before then, an offline retry must keep trying the leave.
    static func withdrawalRetryRequiresRemoteDelete(
        canonicalSnapshotLoaded: Bool,
        partyIsStillPresent: Bool
    ) -> Bool? {
        guard canonicalSnapshotLoaded else { return nil }
        return !partyIsStillPresent
    }

    /// An old service cannot acknowledge archive deletion. A previously
    /// persisted withdrawal remains a privacy boundary until that capability
    /// returns; a new deletion must not create unsupported remote work.
    static func archiveDeletionDisposition(
        supportsSharedHabits: Bool,
        fence: NightFlockSharedHabitsPrivacyFence?
    ) -> ArchiveDeletionDisposition {
        if supportsSharedHabits { return .send }
        return fence?.action == .withdrawHistory ? .preservePendingFence : .unavailable
    }

    /// Legacy V4 parties have no archive command to fence. Their established
    /// leave/dissolve transport stays independent of shared-habits publication.
    static func partyExitDisposition(
        supportsSharedHabits: Bool
    ) -> PartyExitDisposition {
        supportsSharedHabits ? .stageSharedHabitsFence : .sendLegacyCommand
    }
}
