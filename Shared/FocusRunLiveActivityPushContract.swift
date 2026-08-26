import Foundation

enum LiveActivityAPNSEnvironment: String, Codable, Hashable {
    case sandbox
    case production
}

enum FocusRunCloudStatus: String, Codable, Hashable {
    case active
    case completed
    case endedEarly = "ended_early"
    case cancelled
}

struct FocusRunCloudSync: Codable, Hashable {
    static let currentSchemaVersion = 1

    var schemaVersion = currentSchemaVersion
    var runID: UUID
    var installationID: UUID
    var plannedEndAt: Date
    var observedAt: Date
    var status: FocusRunCloudStatus
    var runRevision: Int
    var appVersion: String?
    var idempotencyKey: String
}

struct FocusRunLiveActivityPushRegistration: Codable, Hashable {
    static let currentSchemaVersion = 2

    var schemaVersion = currentSchemaVersion
    var runID: UUID
    var activityID: String
    var pushToken: String
    var plannedEndAt: Date
    var observedAt: Date
    var environment: LiveActivityAPNSEnvironment
    var installationID: UUID? = nil
    var runRevision: Int? = nil
    var tokenGeneration: Int? = nil
    var idempotencyKey: String? = nil
    var phase: NightWatchPhase? = nil
    var role: WindDownOccurrenceRole? = nil
    var bedtimeAt: Date? = nil
    var wakeAt: Date? = nil
    var morningQuietEndsAt: Date? = nil
    var eveningActivityTitle: String? = nil
    var morningActivityTitle: String? = nil
}

enum FocusRunLiveActivityCancellationReason: String, Codable, Hashable {
    case completed
    case endedEarly
    case reset
    case replaced
}

struct FocusRunLiveActivityCancellation: Codable, Hashable {
    static let currentSchemaVersion = 2

    var schemaVersion = currentSchemaVersion
    var runID: UUID
    var activityID: String
    var reason: FocusRunLiveActivityCancellationReason
    var occurredAt: Date
    var installationID: UUID? = nil
    var runRevision: Int? = nil
    var idempotencyKey: String? = nil
}
