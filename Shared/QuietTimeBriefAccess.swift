import Foundation

enum QuietTimeBriefAccessRoute: String, Codable, Equatable {
    case application
    case category
    case webDomain
}

enum QuietTimeBriefAccessGrantStatus: String, Codable, Equatable {
    case pending
    case scheduled
}

struct QuietTimeBriefAccessUse: Codable, Equatable {
    let nonce: UUID
    let requestedAt: Date
    let expiresAt: Date
}

struct QuietTimeBriefAccessRunLedgerEntry: Codable, Equatable {
    let runID: UUID
    let successfulUseCount: Int
    let updatedAt: Date
}

/// The identity carried by a Brief Access grant. A legacy snapshot has no
/// occurrence registry, so it deliberately maps to its run identifier at
/// epoch one. Once a registry entry exists, all three values must match
/// before an extension can clear or restore a shield.
struct QuietTimeBriefAccessScheduleIdentity: Equatable {
    let runID: UUID
    let occurrenceID: UUID
    let revision: Int
    let epoch: Int

    init(
        runID: UUID,
        occurrenceID: UUID? = nil,
        revision: Int,
        epoch: Int = 1
    ) {
        self.runID = runID
        self.occurrenceID = occurrenceID ?? runID
        self.revision = max(1, revision)
        self.epoch = max(1, epoch)
    }
}

struct QuietTimeBriefAccessGrant: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    let runID: UUID
    let occurrenceID: UUID
    let scheduleRevision: Int
    let scheduleEpoch: Int
    let requestedAt: Date
    let expiresAt: Date
    let nonce: UUID
    let restoreActivityIdentifier: String
    var status: QuietTimeBriefAccessGrantStatus

    init(
        schemaVersion: Int = currentSchemaVersion,
        runID: UUID,
        occurrenceID: UUID? = nil,
        scheduleRevision: Int,
        scheduleEpoch: Int = 1,
        requestedAt: Date,
        expiresAt: Date,
        nonce: UUID = UUID(),
        restoreActivityIdentifier: String = QuietTimeBriefAccessConstants.restoreActivityIdentifier,
        status: QuietTimeBriefAccessGrantStatus = .pending
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.occurrenceID = occurrenceID ?? runID
        self.scheduleRevision = max(1, scheduleRevision)
        self.scheduleEpoch = max(1, scheduleEpoch)
        self.requestedAt = requestedAt
        self.expiresAt = max(requestedAt, expiresAt)
        self.nonce = nonce
        self.restoreActivityIdentifier = restoreActivityIdentifier
        self.status = status
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, runID, occurrenceID, scheduleRevision, scheduleEpoch, requestedAt, expiresAt
        case nonce, restoreActivityIdentifier, status
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let runID = try container.decode(UUID.self, forKey: .runID)
        self.init(
            schemaVersion: try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion,
            runID: runID,
            occurrenceID: try container.decodeIfPresent(UUID.self, forKey: .occurrenceID) ?? runID,
            scheduleRevision: try container.decodeIfPresent(Int.self, forKey: .scheduleRevision) ?? 1,
            scheduleEpoch: try container.decodeIfPresent(Int.self, forKey: .scheduleEpoch) ?? 1,
            requestedAt: try container.decode(Date.self, forKey: .requestedAt),
            expiresAt: try container.decode(Date.self, forKey: .expiresAt),
            nonce: try container.decodeIfPresent(UUID.self, forKey: .nonce) ?? UUID(),
            restoreActivityIdentifier: try container.decodeIfPresent(String.self, forKey: .restoreActivityIdentifier)
                ?? QuietTimeBriefAccessConstants.restoreActivityIdentifier,
            status: try container.decodeIfPresent(QuietTimeBriefAccessGrantStatus.self, forKey: .status) ?? .pending
        )
    }
}

struct QuietTimeBriefAccessState: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let maximumHistoryCount = 20

    var schemaVersion: Int
    var runID: UUID
    var occurrenceID: UUID
    var scheduleRevision: Int
    var scheduleEpoch: Int
    var successfulUseCount: Int
    var successfulUses: [QuietTimeBriefAccessUse]
    var activeGrant: QuietTimeBriefAccessGrant?
    var completedRunCounts: [QuietTimeBriefAccessRunLedgerEntry]
    /// A monitor may reject a pending grant after the action extension has
    /// started restoration monitoring. Keep the nonce as a durable tombstone
    /// so stale in-memory action state cannot later clear the shield.
    var rejectedGrantNonce: UUID?
    var rejectedAt: Date?
    var archivedAt: Date?
    var updatedAt: Date

    init(
        schemaVersion: Int = currentSchemaVersion,
        runID: UUID,
        occurrenceID: UUID? = nil,
        scheduleRevision: Int,
        scheduleEpoch: Int = 1,
        successfulUseCount: Int = 0,
        successfulUses: [QuietTimeBriefAccessUse] = [],
        activeGrant: QuietTimeBriefAccessGrant? = nil,
        completedRunCounts: [QuietTimeBriefAccessRunLedgerEntry] = [],
        rejectedGrantNonce: UUID? = nil,
        rejectedAt: Date? = nil,
        archivedAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.occurrenceID = occurrenceID ?? runID
        self.scheduleRevision = max(1, scheduleRevision)
        self.scheduleEpoch = max(1, scheduleEpoch)
        self.successfulUseCount = max(successfulUseCount, successfulUses.count)
        self.successfulUses = Array(successfulUses.suffix(Self.maximumHistoryCount))
        self.activeGrant = activeGrant
        self.completedRunCounts = Self.normalizedLedger(completedRunCounts)
        self.rejectedGrantNonce = rejectedGrantNonce
        self.rejectedAt = rejectedAt
        self.archivedAt = archivedAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, runID, occurrenceID, scheduleRevision, scheduleEpoch, successfulUseCount
        case successfulUses, activeGrant, completedRunCounts
        case rejectedGrantNonce, rejectedAt, archivedAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? Self.currentSchemaVersion
        runID = try container.decode(UUID.self, forKey: .runID)
        scheduleRevision = max(
            1,
            try container.decodeIfPresent(Int.self, forKey: .scheduleRevision) ?? 1
        )
        occurrenceID = try container.decodeIfPresent(UUID.self, forKey: .occurrenceID) ?? runID
        scheduleEpoch = max(1, try container.decodeIfPresent(Int.self, forKey: .scheduleEpoch) ?? 1)
        successfulUseCount = max(
            0,
            try container.decodeIfPresent(Int.self, forKey: .successfulUseCount) ?? 0
        )
        successfulUses = Array(
            (try container.decodeIfPresent([QuietTimeBriefAccessUse].self, forKey: .successfulUses) ?? [])
                .suffix(Self.maximumHistoryCount)
        )
        successfulUseCount = max(successfulUseCount, successfulUses.count)
        activeGrant = try container.decodeIfPresent(
            QuietTimeBriefAccessGrant.self,
            forKey: .activeGrant
        )
        completedRunCounts = Self.normalizedLedger(
            try container.decodeIfPresent(
                [QuietTimeBriefAccessRunLedgerEntry].self,
                forKey: .completedRunCounts
            ) ?? []
        )
        rejectedGrantNonce = try container.decodeIfPresent(UUID.self, forKey: .rejectedGrantNonce)
        rejectedAt = try container.decodeIfPresent(Date.self, forKey: .rejectedAt)
        archivedAt = try container.decodeIfPresent(Date.self, forKey: .archivedAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }

    func durableCount(for runID: UUID) -> Int {
        let current = self.runID == runID ? successfulUseCount : 0
        let archived = completedRunCounts.first(where: { $0.runID == runID })?.successfulUseCount ?? 0
        return max(current, archived)
    }

    mutating func propose(_ grant: QuietTimeBriefAccessGrant, at date: Date) -> Bool {
        guard activeGrant == nil,
              grant.runID == runID,
              grant.occurrenceID == occurrenceID,
              grant.scheduleRevision == scheduleRevision,
              grant.scheduleEpoch == scheduleEpoch else { return false }
        activeGrant = grant
        rejectedGrantNonce = nil
        rejectedAt = nil
        archivedAt = nil
        updatedAt = date
        return true
    }

    mutating func markScheduled(nonce: UUID, at date: Date) -> Bool {
        guard var grant = activeGrant,
              grant.nonce == nonce,
              grant.status == .pending else { return false }
        grant.status = .scheduled
        activeGrant = grant
        successfulUseCount += 1
        successfulUses.append(
            QuietTimeBriefAccessUse(
                nonce: grant.nonce,
                requestedAt: grant.requestedAt,
                expiresAt: grant.expiresAt
            )
        )
        successfulUses = Array(successfulUses.suffix(Self.maximumHistoryCount))
        rejectedGrantNonce = nil
        rejectedAt = nil
        archivedAt = nil
        updatedAt = date
        return true
    }

    mutating func rejectPendingGrant(nonce: UUID, at date: Date) {
        guard activeGrant?.nonce == nonce,
              activeGrant?.status == .pending else { return }
        activeGrant = nil
        rejectedGrantNonce = nonce
        rejectedAt = date
        updatedAt = date
    }

    mutating func rollback(nonce: UUID, at date: Date) {
        guard activeGrant?.nonce == nonce else { return }
        activeGrant = nil
        updatedAt = date
    }

    mutating func clearActiveGrant(at date: Date) {
        archiveCurrentRun(at: date)
    }

    mutating func archiveCurrentRun(at date: Date) {
        if successfulUseCount > 0 {
            completedRunCounts.removeAll { $0.runID == runID }
            completedRunCounts.insert(
                QuietTimeBriefAccessRunLedgerEntry(
                    runID: runID,
                    successfulUseCount: successfulUseCount,
                    updatedAt: date
                ),
                at: 0
            )
            completedRunCounts = Self.normalizedLedger(completedRunCounts)
        }
        activeGrant = nil
        archivedAt = date
        updatedAt = date
    }

    mutating func carryingLedgerForward(
        to runID: UUID,
        occurrenceID: UUID? = nil,
        revision: Int,
        epoch: Int = 1,
        at date: Date
    ) {
        archiveCurrentRun(at: date)
        self.runID = runID
        self.occurrenceID = occurrenceID ?? runID
        scheduleRevision = max(1, revision)
        scheduleEpoch = max(1, epoch)
        successfulUseCount = 0
        successfulUses = []
        activeGrant = nil
        rejectedGrantNonce = nil
        rejectedAt = nil
        archivedAt = nil
        updatedAt = date
    }

    private static func normalizedLedger(
        _ entries: [QuietTimeBriefAccessRunLedgerEntry]
    ) -> [QuietTimeBriefAccessRunLedgerEntry] {
        var latest: [UUID: QuietTimeBriefAccessRunLedgerEntry] = [:]
        for entry in entries {
            guard entry.successfulUseCount > 0 else { continue }
            if let old = latest[entry.runID], old.updatedAt >= entry.updatedAt { continue }
            latest[entry.runID] = entry
        }
        return latest.values.sorted { $0.updatedAt > $1.updatedAt }.prefix(Self.maximumHistoryCount).map { $0 }
    }
}

enum QuietTimeBriefAccessConstants {
    static let duration: TimeInterval = 5 * 60
    static let minimumSchedulingLead: TimeInterval = 1
    static let minimumGrantDuration: TimeInterval = 2
    /// DeviceActivity rejects one-shot intervals shorter than fifteen minutes.
    /// The restore callback is therefore a warning inside a longer envelope.
    static let minimumRestoreMonitoringDuration: TimeInterval = 15 * 60
    static let restoreActivityIdentifier = "ollie.quietTime.briefAccessRestore"
}

struct QuietTimeBriefAccessRestorePlan: Equatable {
    let intervalStart: Date
    let intervalEnd: Date
    let warningTime: DateComponents

    var duration: TimeInterval { intervalEnd.timeIntervalSince(intervalStart) }

    static func make(requestedAt: Date, expiresAt: Date) -> Self? {
        let intervalStart = requestedAt.addingTimeInterval(
            QuietTimeBriefAccessConstants.minimumSchedulingLead
        )
        guard expiresAt > intervalStart else { return nil }
        let intervalEnd = max(
            intervalStart.addingTimeInterval(
                QuietTimeBriefAccessConstants.minimumRestoreMonitoringDuration
            ),
            expiresAt.addingTimeInterval(1)
        )
        let warningSeconds = max(1, Int(ceil(intervalEnd.timeIntervalSince(expiresAt))))
        return Self(
            intervalStart: intervalStart,
            intervalEnd: intervalEnd,
            warningTime: DateComponents(
                hour: warningSeconds / 3600,
                minute: (warningSeconds % 3600) / 60,
                second: warningSeconds % 60
            )
        )
    }
}

enum QuietTimeBriefAccessValidation: Equatable {
    case eligible
    case webDomainRejected
    case missingSelection
    case staleRun
    case staleOccurrence
    case staleRevision
    case staleEpoch
    case outsideShieldedPhase
    case activeGrant
    case expiredGrant
}

enum QuietTimeBriefAccessReconciliation: Equatable {
    case noActiveGrant
    case keepShieldClear(until: Date)
    case restoreShield
    case rejectPendingGrant
    case discardStaleGrant
}

enum QuietTimeBriefAccessStaleGrantAction: Equatable {
    case reapplyCurrentShield
    case clearProtection
}

enum QuietTimeBriefAccessPolicy {
    static func makeGrant(
        runID: UUID,
        scheduleRevision: Int,
        requestedAt: Date,
        schedule: QuietTimeShieldScheduleSnapshot,
        occurrenceID: UUID? = nil,
        scheduleEpoch: Int = 1,
        nonce: UUID = UUID()
    ) -> QuietTimeBriefAccessGrant? {
        guard isShieldedPhase(schedule: schedule, at: requestedAt) else { return nil }
        let intervalEnd = shieldedIntervalEnd(schedule: schedule, at: requestedAt)
        let expiresAt = min(
            requestedAt.addingTimeInterval(QuietTimeBriefAccessConstants.duration),
            intervalEnd ?? requestedAt.addingTimeInterval(QuietTimeBriefAccessConstants.duration)
        )
        guard expiresAt.timeIntervalSince(requestedAt) >= QuietTimeBriefAccessConstants.minimumGrantDuration else {
            return nil
        }
        return QuietTimeBriefAccessGrant(
            runID: runID,
            occurrenceID: occurrenceID,
            scheduleRevision: scheduleRevision,
            scheduleEpoch: scheduleEpoch,
            requestedAt: requestedAt,
            expiresAt: expiresAt,
            nonce: nonce
        )
    }

    static func validate(
        route: QuietTimeBriefAccessRoute,
        schedule: QuietTimeShieldScheduleSnapshot,
        state: QuietTimeBriefAccessState?,
        at date: Date,
        hasApplicationOrCategorySelection: Bool,
        occurrenceID: UUID? = nil,
        scheduleEpoch: Int = 1
    ) -> QuietTimeBriefAccessValidation {
        guard route != .webDomain else { return .webDomainRejected }
        guard hasApplicationOrCategorySelection else { return .missingSelection }
        guard schedule.isEligible(at: date), isShieldedPhase(schedule: schedule, at: date) else {
            return .outsideShieldedPhase
        }
        if let state {
            guard state.runID == schedule.runID else { return .staleRun }
            guard state.occurrenceID == (occurrenceID ?? schedule.runID) else { return .staleOccurrence }
            guard state.scheduleRevision == schedule.revision else { return .staleRevision }
            guard state.scheduleEpoch == max(1, scheduleEpoch) else { return .staleEpoch }
            if let grant = state.activeGrant {
                return date < grant.expiresAt ? .activeGrant : .expiredGrant
            }
        }
        return .eligible
    }

    static func reconciliation(
        state: QuietTimeBriefAccessState?,
        schedule: QuietTimeShieldScheduleSnapshot?,
        currentRunID: UUID,
        currentRevision: Int,
        currentOccurrenceID: UUID? = nil,
        currentEpoch: Int = 1,
        at date: Date,
        terminal: Bool = false
    ) -> QuietTimeBriefAccessReconciliation {
        guard let state, let grant = state.activeGrant else { return .noActiveGrant }
        guard !terminal,
              let schedule,
              state.runID == currentRunID,
              grant.runID == currentRunID,
              state.occurrenceID == (currentOccurrenceID ?? currentRunID),
              grant.occurrenceID == (currentOccurrenceID ?? currentRunID),
              state.scheduleRevision == currentRevision,
              grant.scheduleRevision == currentRevision,
              state.scheduleEpoch == max(1, currentEpoch),
              grant.scheduleEpoch == max(1, currentEpoch),
              grant.restoreActivityIdentifier == QuietTimeBriefAccessConstants.restoreActivityIdentifier,
              grant.status == .scheduled || grant.status == .pending else {
            return .discardStaleGrant
        }
        if grant.status == .pending { return .rejectPendingGrant }
        guard date < grant.expiresAt else {
            return isShieldedPhase(schedule: schedule, at: date)
                ? .restoreShield
                : .discardStaleGrant
        }
        return .keepShieldClear(until: grant.expiresAt)
    }

    static func canCommitScheduledGrant(
        state: QuietTimeBriefAccessState?,
        grant: QuietTimeBriefAccessGrant,
        currentRunID: UUID,
        currentRevision: Int,
        currentOccurrenceID: UUID? = nil,
        currentEpoch: Int = 1
    ) -> Bool {
        guard let state,
              state.runID == currentRunID,
              state.occurrenceID == (currentOccurrenceID ?? currentRunID),
              state.scheduleRevision == currentRevision,
              state.scheduleEpoch == max(1, currentEpoch),
              grant.runID == currentRunID,
              grant.occurrenceID == (currentOccurrenceID ?? currentRunID),
              grant.scheduleRevision == currentRevision,
              grant.scheduleEpoch == max(1, currentEpoch),
              state.rejectedGrantNonce != grant.nonce,
              state.archivedAt == nil,
              let activeGrant = state.activeGrant,
              activeGrant == grant,
              activeGrant.status == .pending else { return false }
        return true
    }

    /// A pending grant can be left behind if the Shield Action extension is
    /// terminated after scheduling the restore activity but before it records
    /// the successful grant. Reconcile that crash window against the current
    /// schedule instead of treating the pending record as permission to clear.
    static func staleGrantAction(
        schedule: QuietTimeShieldScheduleSnapshot?,
        at date: Date,
        hasActiveRegistryProtection: Bool = false
    ) -> QuietTimeBriefAccessStaleGrantAction {
        if hasActiveRegistryProtection { return .reapplyCurrentShield }
        guard let schedule,
              schedule.isEligible(at: date),
              isShieldedPhase(schedule: schedule, at: date) else {
            return .clearProtection
        }
        return .reapplyCurrentShield
    }

    static func shouldRestore(at date: Date, for grant: QuietTimeBriefAccessGrant) -> Bool {
        date >= grant.expiresAt
    }

    static func isShieldedPhase(
        schedule: QuietTimeShieldScheduleSnapshot,
        at date: Date
    ) -> Bool {
        schedule.contains(date, in: .protectedSession)
            || schedule.contains(date, in: .windDown)
            || schedule.contains(date, in: .morningQuiet)
    }

    private static func shieldedIntervalEnd(
        schedule: QuietTimeShieldScheduleSnapshot,
        at date: Date
    ) -> Date? {
        if !schedule.repeatsDaily {
            return QuietTimeShieldWindow.allCases
                .compactMap { window in
                    guard schedule.contains(date, in: window) else { return nil }
                    return schedule.interval(for: window)?.end
                }
                .min()
        }

        let calendar = Calendar.current
        let current = calendar.dateComponents([.hour, .minute, .second], from: date)
        let currentSeconds = (current.hour ?? 0) * 3600
            + (current.minute ?? 0) * 60
            + (current.second ?? 0)
        let dayStart = calendar.startOfDay(for: date)
        return QuietTimeShieldWindow.allCases.compactMap { window in
            guard let interval = schedule.interval(for: window),
                  schedule.contains(date, in: window) else { return nil }
            let end = calendar.dateComponents([.hour, .minute, .second], from: interval.end)
            let endSeconds = (end.hour ?? 0) * 3600
                + (end.minute ?? 0) * 60
                + (end.second ?? 0)
            let dayOffset = endSeconds <= currentSeconds ? 1 : 0
            let endDay = calendar.date(byAdding: .day, value: dayOffset, to: dayStart) ?? dayStart
            return calendar.date(
                bySettingHour: end.hour ?? 0,
                minute: end.minute ?? 0,
                second: end.second ?? 0,
                of: endDay
            )
        }.min()
    }
}
