import Foundation

enum NotificationCadence: String, Codable, CaseIterable, Identifiable {
    case quiet
    case balanced
    case supportive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quiet: return "Quiet"
        case .balanced: return "Balanced"
        case .supportive: return "Supportive"
        }
    }

    var detail: String {
        switch self {
        case .quiet: return "A few gentle boundary cues."
        case .balanced: return "A little more help inside the quiet windows."
        case .supportive: return "The fullest trail of reminders Ollie offers."
        }
    }

    var leadInMinutes: [Int] {
        switch self {
        case .quiet: return []
        case .balanced: return [30, 10]
        case .supportive: return [60, 30, 10]
        }
    }

    var includesWindDownMidpoint: Bool { self != .quiet }
    var includesMorningMidpoint: Bool { self == .supportive }

    var scheduledTouchpointCount: Int {
        4 + leadInMinutes.count
            + (includesWindDownMidpoint ? 1 : 0)
            + (includesMorningMidpoint ? 1 : 0)
    }
}

struct NotificationPreferences: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var remindersEnabled: Bool
    var cadence: NotificationCadence
    var hasChosenCadence: Bool
    var soundsEnabled: Bool
    var educationalTipsEnabled: Bool
    var usageAwareRemindersEnabled: Bool
    var morningReflectionReminderEnabled: Bool

    static let defaults = NotificationPreferences(
        remindersEnabled: true,
        cadence: .balanced,
        hasChosenCadence: false,
        soundsEnabled: true,
        educationalTipsEnabled: false,
        usageAwareRemindersEnabled: false,
        morningReflectionReminderEnabled: false
    )

    init(
        schemaVersion: Int = currentSchemaVersion,
        remindersEnabled: Bool,
        cadence: NotificationCadence,
        hasChosenCadence: Bool,
        soundsEnabled: Bool,
        educationalTipsEnabled: Bool,
        usageAwareRemindersEnabled: Bool,
        morningReflectionReminderEnabled: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.remindersEnabled = remindersEnabled
        self.cadence = cadence
        self.hasChosenCadence = hasChosenCadence
        self.soundsEnabled = soundsEnabled
        self.educationalTipsEnabled = educationalTipsEnabled
        self.usageAwareRemindersEnabled = usageAwareRemindersEnabled
        self.morningReflectionReminderEnabled = morningReflectionReminderEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        remindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? true
        cadence = try container.decodeIfPresent(NotificationCadence.self, forKey: .cadence) ?? .balanced
        hasChosenCadence = try container.decodeIfPresent(Bool.self, forKey: .hasChosenCadence) ?? false
        soundsEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundsEnabled) ?? true
        educationalTipsEnabled = try container.decodeIfPresent(Bool.self, forKey: .educationalTipsEnabled) ?? false
        usageAwareRemindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .usageAwareRemindersEnabled) ?? false
        morningReflectionReminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .morningReflectionReminderEnabled) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, remindersEnabled, cadence, hasChosenCadence, soundsEnabled
        case educationalTipsEnabled, usageAwareRemindersEnabled, morningReflectionReminderEnabled
    }
}

enum NotificationImportance: String, Codable, Equatable {
    case passive
    case active
}

enum NotificationDestination: String, Codable, Equatable {
    case home
    case activeRun
    case nights
    case morningReflection
}

struct PlannedNotification: Codable, Equatable, Identifiable {
    let id: String
    let date: Date
    let title: String
    let body: String
    let phase: NightWatchPhase
    let importance: NotificationImportance
    let playsSound: Bool
    let destination: NotificationDestination
}
