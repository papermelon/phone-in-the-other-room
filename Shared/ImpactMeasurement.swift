import Foundation

struct NightImpactSample: Equatable, Identifiable {
    var nightEndingDate: Date
    var plannedQuietMinutes: Int
    var quietMinutes: Int
    var completedRitual: Bool
    var startMethod: SessionGuardKind?
    var shieldEvidence: ShieldProtectionEvidence
    var sleepMinutes: Int?
    var coreSleepMinutes: Int?
    var deepSleepMinutes: Int?
    var remSleepMinutes: Int?
    var restfulness: MorningRestfulness?

    var id: Date { nightEndingDate }
}

struct SleepOutcomeComparison: Equatable {
    var protectedNightCount: Int
    var baselineNightCount: Int
    var protectedAverageSleepMinutes: Int
    var baselineAverageSleepMinutes: Int
    var quietSleepCorrelation: Double?

    var differenceMinutes: Int {
        protectedAverageSleepMinutes - baselineAverageSleepMinutes
    }
}

enum ImpactMeasurementEngine {
    static func samples(
        history: NightWatchHistory,
        sleeps: [SleepSummary],
        checkIns: MorningCheckInHistory,
        calendar: Calendar = .current
    ) -> [NightImpactSample] {
        let sleepByDay = Dictionary(
            sleeps.compactMap { summary -> (Date, SleepSummary)? in
                guard let date = summary.nightEndingDate ?? summary.endDate else { return nil }
                return (calendar.startOfDay(for: date), summary)
            },
            uniquingKeysWith: { first, _ in first }
        )
        let recordByDay = Dictionary(
            history.records.map {
                (calendar.startOfDay(for: $0.plan.wakeTime), $0)
            },
            uniquingKeysWith: { first, second in
                first.updatedAt >= second.updatedAt ? first : second
            }
        )
        let days = Set(sleepByDay.keys).union(recordByDay.keys)

        return days.sorted(by: >).map { day in
            let record = recordByDay[day]
            let sleep = sleepByDay[day]
            let stages = sleep?.stages
            return NightImpactSample(
                nightEndingDate: day,
                plannedQuietMinutes: (record?.plan.windDownMinutes ?? 0)
                    + (record?.plan.morningQuietMinutes ?? 0),
                quietMinutes: (record?.creditedWindDownMinutes ?? 0)
                    + (record?.creditedMorningQuietMinutes ?? 0),
                completedRitual: record?.outcome == .completed,
                startMethod: record?.startMethod,
                shieldEvidence: record?.shieldProtectionEvidence ?? .notRequested,
                sleepMinutes: sleep.map { Int($0.durationSeconds / 60) },
                coreSleepMinutes: stageMinutes(stages?.coreSeconds, available: stages?.hasStages),
                deepSleepMinutes: stageMinutes(stages?.deepSeconds, available: stages?.hasStages),
                remSleepMinutes: stageMinutes(stages?.remSeconds, available: stages?.hasStages),
                restfulness: checkIns.entry(for: day, calendar: calendar)?.restfulness
            )
        }
    }

    static func sleepComparison(
        for samples: [NightImpactSample],
        minimumGroupSize: Int = 2
    ) -> SleepOutcomeComparison? {
        let protected = samples.compactMap { sample -> Int? in
            guard sample.completedRitual else { return nil }
            return sample.sleepMinutes
        }
        let baseline = samples.compactMap { sample -> Int? in
            guard !sample.completedRitual else { return nil }
            return sample.sleepMinutes
        }
        guard protected.count >= minimumGroupSize,
              baseline.count >= minimumGroupSize else { return nil }

        let pairs = samples.compactMap { sample -> (Double, Double)? in
            guard let sleep = sample.sleepMinutes else { return nil }
            return (Double(sample.quietMinutes), Double(sleep))
        }
        return SleepOutcomeComparison(
            protectedNightCount: protected.count,
            baselineNightCount: baseline.count,
            protectedAverageSleepMinutes: average(protected),
            baselineAverageSleepMinutes: average(baseline),
            quietSleepCorrelation: pearson(pairs)
        )
    }

    static func uploadRecords(
        for samples: [NightImpactSample],
        consentedAt: Date,
        existingIDs: [Int: UUID] = [:],
        appVersion: String,
        calendar: Calendar = .current
    ) -> [ImpactUploadRecord] {
        let consentDay = calendar.startOfDay(for: consentedAt)
        return samples.compactMap { sample in
            let day = calendar.startOfDay(for: sample.nightEndingDate)
            let relativeNight = calendar.dateComponents(
                [.day],
                from: consentDay,
                to: day
            ).day ?? 0
            guard (-30...3650).contains(relativeNight) else { return nil }
            return ImpactUploadRecord(
                id: existingIDs[relativeNight] ?? UUID(),
                relativeNight: relativeNight,
                sample: sample,
                appVersion: appVersion
            )
        }
    }

    private static func stageMinutes(
        _ seconds: TimeInterval?,
        available: Bool?
    ) -> Int? {
        guard available == true, let seconds else { return nil }
        return Int(seconds / 60)
    }

    private static func average(_ values: [Int]) -> Int {
        Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    private static func pearson(_ pairs: [(Double, Double)]) -> Double? {
        guard pairs.count >= 3 else { return nil }
        let xMean = pairs.reduce(0) { $0 + $1.0 } / Double(pairs.count)
        let yMean = pairs.reduce(0) { $0 + $1.1 } / Double(pairs.count)
        let numerator = pairs.reduce(0) {
            $0 + ($1.0 - xMean) * ($1.1 - yMean)
        }
        let xVariance = pairs.reduce(0) { $0 + pow($1.0 - xMean, 2) }
        let yVariance = pairs.reduce(0) { $0 + pow($1.1 - yMean, 2) }
        let denominator = sqrt(xVariance * yVariance)
        return denominator > 0 ? numerator / denominator : nil
    }
}

struct ImpactSharingPreferences: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var isEnabled: Bool
    var consentedAt: Date?

    init(
        schemaVersion: Int = currentSchemaVersion,
        isEnabled: Bool = false,
        consentedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.isEnabled = isEnabled
        self.consentedAt = consentedAt
    }
}

struct ImpactUploadRecord: Codable, Equatable, Identifiable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: UUID
    var relativeNight: Int
    var plannedQuietMinutes: Int
    var quietMinutes: Int
    var completedRitual: Bool
    var startMethod: String?
    var shieldEvidence: String
    var sleepMinutes: Int?
    var coreSleepMinutes: Int?
    var deepSleepMinutes: Int?
    var remSleepMinutes: Int?
    var restfulness: String?
    var appVersion: String

    init(
        id: UUID = UUID(),
        relativeNight: Int,
        sample: NightImpactSample,
        appVersion: String
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.relativeNight = relativeNight
        plannedQuietMinutes = sample.plannedQuietMinutes
        quietMinutes = sample.quietMinutes
        completedRitual = sample.completedRitual
        startMethod = sample.startMethod?.rawValue
        shieldEvidence = sample.shieldEvidence.rawValue
        sleepMinutes = sample.sleepMinutes
        coreSleepMinutes = sample.coreSleepMinutes
        deepSleepMinutes = sample.deepSleepMinutes
        remSleepMinutes = sample.remSleepMinutes
        restfulness = sample.restfulness?.rawValue
        self.appVersion = appVersion
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case id
        case relativeNight = "relative_night"
        case plannedQuietMinutes = "planned_quiet_minutes"
        case quietMinutes = "quiet_minutes"
        case completedRitual = "completed_ritual"
        case startMethod = "start_method"
        case shieldEvidence = "shield_evidence"
        case sleepMinutes = "sleep_minutes"
        case coreSleepMinutes = "core_sleep_minutes"
        case deepSleepMinutes = "deep_sleep_minutes"
        case remSleepMinutes = "rem_sleep_minutes"
        case restfulness
        case appVersion = "app_version"
    }
}
