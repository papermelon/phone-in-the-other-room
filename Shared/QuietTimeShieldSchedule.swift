import Foundation

enum QuietTimeShieldWindow: String, Codable, CaseIterable, Equatable {
    case protectedSession
    case windDown
    case morningQuiet
}

struct QuietTimeShieldScheduleSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 3

    var schemaVersion: Int
    var runID: UUID
    var revision: Int
    var role: QuietTimeShieldRole
    /// The actual app-limit interval. Unlike the two credited bookends, this
    /// can span the overnight phase when the user chooses the NFC barrier.
    var protectedSessionInterval: DateInterval?
    var windDownInterval: DateInterval?
    var morningQuietInterval: DateInterval
    var updatedAt: Date
    var repeatsDaily: Bool

    init(
        schemaVersion: Int = currentSchemaVersion,
        runID: UUID,
        revision: Int,
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
        self.role = role
        self.protectedSessionInterval = protectedSessionInterval
        self.windDownInterval = windDownInterval
        self.morningQuietInterval = morningQuietInterval
        self.updatedAt = updatedAt
        self.repeatsDaily = repeatsDaily
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, runID, revision, role, protectedSessionInterval, windDownInterval, morningQuietInterval
        case updatedAt, repeatsDaily
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? Self.currentSchemaVersion
        schemaVersion = max(storedSchemaVersion, Self.currentSchemaVersion)
        runID = try container.decode(UUID.self, forKey: .runID)
        revision = max(1, try container.decodeIfPresent(Int.self, forKey: .revision) ?? 1)
        role = try container.decodeIfPresent(QuietTimeShieldRole.self, forKey: .role)
            ?? .primaryWindDown
        protectedSessionInterval = try container.decodeIfPresent(DateInterval.self, forKey: .protectedSessionInterval)
        windDownInterval = try container.decodeIfPresent(DateInterval.self, forKey: .windDownInterval)
        morningQuietInterval = try container.decode(DateInterval.self, forKey: .morningQuietInterval)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        repeatsDaily = try container.decodeIfPresent(Bool.self, forKey: .repeatsDaily) ?? false
    }

    func interval(for window: QuietTimeShieldWindow) -> DateInterval? {
        switch window {
        case .protectedSession: return protectedSessionInterval
        case .windDown: return windDownInterval
        case .morningQuiet: return morningQuietInterval
        }
    }

    func contains(_ date: Date, in window: QuietTimeShieldWindow) -> Bool {
        guard let interval = interval(for: window) else { return false }
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

    /// A repeating schedule is only allowed to act on or after the first window
    /// it was installed for. This prevents a late callback from a superseded
    /// DeviceActivity schedule from applying tomorrow's schedule today.
    func isEligible(at date: Date) -> Bool {
        // A session that starts after bedtime can have no wind-down bookend.
        // Its protected interval is still valid immediately; using morningQuiet
        // as the fallback would make the monitor clear an overnight shield.
        let firstWindowStart = protectedSessionInterval?.start
            ?? windDownInterval?.start
            ?? morningQuietInterval.start
        return date >= firstWindowStart
    }

    func hasSameWindows(as other: QuietTimeShieldScheduleSnapshot) -> Bool {
        runID == other.runID
            && protectedSessionInterval == other.protectedSessionInterval
            && windDownInterval == other.windDownInterval
            && morningQuietInterval == other.morningQuietInterval
            && role == other.role
            && repeatsDaily == other.repeatsDaily
    }
}

enum QuietTimeShieldSchedulePolicy {
    static func activeWindow(
        in snapshot: QuietTimeShieldScheduleSnapshot,
        at date: Date
    ) -> QuietTimeShieldWindow? {
        QuietTimeShieldWindow.allCases.first {
            snapshot.isEligible(at: date) && snapshot.contains(date, in: $0)
        }
    }
}

enum QuietTimeShieldStatus: String, Codable, Equatable {
    case scheduled
    case applied
    case cleared
    case failed
}

struct QuietTimeShieldStatusSnapshot: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var runID: UUID
    var revision: Int
    var status: QuietTimeShieldStatus
    var window: QuietTimeShieldWindow?
    var observedAt: Date
    var failureCode: String?

    init(
        schemaVersion: Int = currentSchemaVersion,
        runID: UUID,
        revision: Int,
        status: QuietTimeShieldStatus,
        window: QuietTimeShieldWindow?,
        observedAt: Date,
        failureCode: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.runID = runID
        self.revision = max(1, revision)
        self.status = status
        self.window = window
        self.observedAt = observedAt
        self.failureCode = failureCode
    }
}

enum QuietTimeShieldSharedStorage {
    static let scheduleKey = "ollie.screenTime.shieldSchedule"
    static let statusKey = "ollie.screenTime.shieldStatus"
    static let statusHistoryKey = "ollie.screenTime.shieldStatusHistory"
    static let briefAccessStateKey = "ollie.screenTime.briefAccessState"
}

struct QuietTimeShieldProtectionSummary: Equatable {
    var windDownMinutes: Int
    var morningQuietMinutes: Int
    var evidence: ShieldProtectionEvidence

    static let none = QuietTimeShieldProtectionSummary(
        windDownMinutes: 0,
        morningQuietMinutes: 0,
        evidence: .notRequested
    )
}

enum QuietTimeShieldEvidenceMath {
    static func summary(
        for run: FocusRun,
        statuses: [QuietTimeShieldStatusSnapshot],
        at endDate: Date,
        additionalRunIDs: Set<UUID> = []
    ) -> QuietTimeShieldProtectionSummary {
        guard let schedule = QuietTimeShieldScheduleBuilder.snapshot(
            for: run,
            revision: 1,
            updatedAt: run.startedAt
        ) else { return .none }
        let relevant = statuses
            .filter { $0.runID == run.id || additionalRunIDs.contains($0.runID) }
            .sorted { $0.observedAt < $1.observedAt }
        let windDown = protectedSeconds(
            in: schedule.windDownInterval,
            window: .windDown,
            statuses: relevant.filter { $0.window == .windDown || $0.window == .protectedSession },
            endDate: endDate
        )
        let morning = protectedSeconds(
            in: schedule.morningQuietInterval,
            window: .morningQuiet,
            statuses: relevant.filter { $0.window == .morningQuiet || $0.window == .protectedSession },
            endDate: endDate
        )
        let appliedWindows = Set(
            relevant.compactMap {
                $0.status == .applied ? $0.window : nil
            }
        )
        let evidence: ShieldProtectionEvidence
        let hasContinuousProtection = schedule.protectedSessionInterval != nil
            && appliedWindows.contains(.protectedSession)
        let hasLegacyBookendProtection = appliedWindows.isSuperset(of: [.windDown, .morningQuiet])
        if hasContinuousProtection || hasLegacyBookendProtection {
            evidence = .observed
        } else if !appliedWindows.isEmpty {
            evidence = .partial
        } else if relevant.contains(where: { $0.status == .failed }) {
            evidence = .unavailable
        } else {
            evidence = .notRequested
        }
        return QuietTimeShieldProtectionSummary(
            windDownMinutes: Int(windDown / 60),
            morningQuietMinutes: Int(morning / 60),
            evidence: evidence
        )
    }

    private static func protectedSeconds(
        in interval: DateInterval?,
        window: QuietTimeShieldWindow,
        statuses: [QuietTimeShieldStatusSnapshot],
        endDate: Date
    ) -> TimeInterval {
        guard let interval else { return 0 }
        let windowStatuses = statuses.filter {
            $0.window == window || $0.window == .protectedSession
        }
        var start: Date?
        var protected: TimeInterval = 0
        for status in windowStatuses {
            switch status.status {
            case .applied:
                start = start ?? max(status.observedAt, interval.start)
            case .cleared, .failed:
                if let start {
                    protected += max(
                        0,
                        min(status.observedAt, interval.end).timeIntervalSince(start)
                    )
                }
                start = nil
            case .scheduled:
                break
            }
        }
        if let start {
            protected += max(
                0,
                min(endDate, interval.end).timeIntervalSince(start)
            )
        }
        return min(interval.duration, protected)
    }
}

enum QuietTimeShieldScheduleBuilder {
    static func snapshot(
        for run: FocusRun,
        revision: Int,
        updatedAt: Date = Date()
    ) -> QuietTimeShieldScheduleSnapshot? {
        guard let plan = run.nightWatchPlan else { return nil }
        let protectedStart: Date?
        if run.guardKind == .nfcTag {
            // An active NFC run cannot be scheduled before its barrier tap. A
            // terminal legacy record may not have persisted placement metadata,
            // but its factual receipt still needs to decode for history.
            let terminal = [.setup, .completed, .endedEarly].contains(run.state)
            guard run.placementStatus == .confirmed || terminal else { return nil }
            protectedStart = run.phoneAwayValidatedAt ?? run.startedAt
        } else {
            protectedStart = run.startedAt
        }
        return snapshot(
            runID: run.id,
            plan: plan,
            startedAt: protectedStart ?? run.startedAt,
            protectedStart: protectedStart,
            revision: revision,
            updatedAt: updatedAt
        )
    }

    static func snapshot(
        for schedule: AutomaticWindDownSchedule,
        revision: Int,
        updatedAt: Date = Date()
    ) -> QuietTimeShieldScheduleSnapshot {
        snapshot(
            runID: schedule.id,
            plan: schedule.plan,
            startedAt: schedule.startedAt,
            protectedStart: schedule.startedAt,
            revision: revision,
            updatedAt: updatedAt,
            repeatsDaily: true
        )
    }

    private static func snapshot(
        runID: UUID,
        plan: NightWatchPlan,
        startedAt: Date,
        protectedStart: Date?,
        revision: Int,
        updatedAt: Date,
        repeatsDaily: Bool = false
    ) -> QuietTimeShieldScheduleSnapshot {
        let plannedWindDownStart = plan.intendedBedtime.addingTimeInterval(
            TimeInterval(-plan.windDownMinutes * 60)
        )
        let windDownStart = max(startedAt, plannedWindDownStart)
        let windDownInterval = windDownStart < plan.intendedBedtime
            ? DateInterval(start: windDownStart, end: plan.intendedBedtime)
            : nil
        return QuietTimeShieldScheduleSnapshot(
            runID: runID,
            revision: revision,
            role: plan.role == .additionalQuiet ? .additionalQuiet : .primaryWindDown,
            protectedSessionInterval: protectedStart.map {
                DateInterval(start: $0, end: plan.protectedUntil)
            },
            windDownInterval: windDownInterval,
            morningQuietInterval: DateInterval(
                start: plan.wakeTime,
                end: plan.protectedUntil
            ),
            updatedAt: updatedAt,
            repeatsDaily: repeatsDaily
        )
    }
}

#if os(iOS) && canImport(DeviceActivity)
import DeviceActivity

extension DeviceActivityName {
    static let ollieProtectedSession = Self("ollie.quietTime.protectedSession")
    static let ollieWindDown = Self("ollie.quietTime.windDown")
    static let ollieMorningQuiet = Self("ollie.quietTime.morningQuiet")
    static let ollieBriefAccessRestore = Self(QuietTimeBriefAccessConstants.restoreActivityIdentifier)
}

extension QuietTimeShieldWindow {
    var activityName: DeviceActivityName {
        switch self {
        case .protectedSession: return .ollieProtectedSession
        case .windDown: return .ollieWindDown
        case .morningQuiet: return .ollieMorningQuiet
        }
    }

    init?(activityName: DeviceActivityName) {
        switch activityName {
        case .ollieProtectedSession: self = .protectedSession
        case .ollieWindDown: self = .windDown
        case .ollieMorningQuiet: self = .morningQuiet
        default: return nil
        }
    }
}
#endif
