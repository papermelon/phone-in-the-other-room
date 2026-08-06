import Foundation

enum NotificationTemplateID: String, Codable, CaseIterable, Identifiable {
    case windDownLeadIn60
    case windDownLeadIn30
    case windDownLeadIn10
    case windDownStart
    case windDownMidpoint
    case sleepTime
    case phoneFreeMorning
    case morningMidpoint
    case complete
    case morningReflection
    case usageWindDown
    case usageOvernight
    case usageMorningQuiet
    case quietPeriodComplete
    case shieldingFailed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .windDownLeadIn60: return "One hour before Wind Down"
        case .windDownLeadIn30: return "Thirty minutes before Wind Down"
        case .windDownLeadIn10: return "Ten minutes before Wind Down"
        case .windDownStart: return "Wind Down starts"
        case .windDownMidpoint: return "Wind Down midpoint"
        case .sleepTime: return "Bedtime"
        case .phoneFreeMorning: return "Morning quiet starts"
        case .morningMidpoint: return "Morning quiet midpoint"
        case .complete: return "Wind Down completes"
        case .morningReflection: return "Morning reflection"
        case .usageWindDown: return "Wind Down usage cue"
        case .usageOvernight: return "Overnight usage cue"
        case .usageMorningQuiet: return "Morning quiet usage cue"
        case .quietPeriodComplete: return "Additional quiet period completes"
        case .shieldingFailed: return "Shielding failure"
        }
    }

    var detail: String {
        switch self {
        case .windDownLeadIn60, .windDownLeadIn30, .windDownLeadIn10:
            return "A gentle lead-in before the phone rests."
        case .windDownStart: return "The beginning of the before-bed quiet window."
        case .windDownMidpoint: return "A cue inside the before-bed quiet window."
        case .sleepTime: return "The transition into the overnight period."
        case .phoneFreeMorning: return "The beginning of the after-waking quiet window."
        case .morningMidpoint: return "A cue inside the morning quiet window."
        case .complete: return "The end of the phone-away ritual."
        case .morningReflection: return "An optional private morning reflection prompt."
        case .usageWindDown, .usageOvernight, .usageMorningQuiet:
            return "An optional cue after selected-app activity."
        case .quietPeriodComplete: return "The receipt for an additional bounded quiet period."
        case .shieldingFailed: return "Kept fixed so the protection status stays accurate."
        }
    }

    var isEditable: Bool {
        self != .shieldingFailed
    }

    var minutes: Int? {
        switch self {
        case .windDownLeadIn60: return 60
        case .windDownLeadIn30: return 30
        case .windDownLeadIn10: return 10
        default: return nil
        }
    }

    static func from(notificationID id: String) -> Self? {
        switch id {
        case "night-watch-lead-in-60": return .windDownLeadIn60
        case "night-watch-lead-in-30": return .windDownLeadIn30
        case "night-watch-lead-in-10": return .windDownLeadIn10
        case "night-watch-wind-down-start", "night-watch-reminder": return .windDownStart
        case "night-watch-wind-down-midpoint": return .windDownMidpoint
        case "night-watch-sleep-time": return .sleepTime
        case "night-watch-phone-free-morning": return .phoneFreeMorning
        case "night-watch-morning-midpoint": return .morningMidpoint
        case "focus-run-complete": return .complete
        case "night-watch-morning-reflection": return .morningReflection
        case "night-watch-usage-windDown": return .usageWindDown
        case "night-watch-usage-overnight": return .usageOvernight
        case "night-watch-usage-morningQuiet": return .usageMorningQuiet
        case "night-watch-quiet-period-complete": return .quietPeriodComplete
        case "night-watch-shielding-failed": return .shieldingFailed
        default: return nil
        }
    }
}

struct NotificationCopyOverride: Codable, Equatable, Identifiable {
    static let maximumTitleLength = 60
    static let maximumBodyLength = 240

    let id: NotificationTemplateID
    var title: String?
    var body: String?

    init(id: NotificationTemplateID, title: String? = nil, body: String? = nil) {
        self.id = id
        self.title = Self.normalized(title, maximumLength: Self.maximumTitleLength)
        self.body = Self.normalized(body, maximumLength: Self.maximumBodyLength)
    }

    var isEmpty: Bool { title == nil && body == nil }

    private static func normalized(_ value: String?, maximumLength: Int) -> String? {
        guard let value else { return nil }
        let collapsed = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(maximumLength))
    }
}

struct NotificationCopyContext: Equatable {
    var activityTitle: String? = nil
    var purpose: String? = nil
    var tip: String? = nil
    var date: Date? = nil
    var minutes: Int? = nil

    static let empty = NotificationCopyContext()

    var values: [String: String] {
        var result: [String: String] = [:]
        if let activityTitle, !activityTitle.isEmpty { result["activity"] = activityTitle }
        if let purpose, !purpose.isEmpty { result["purpose"] = purpose }
        if let date { result["time"] = date.formatted(date: .omitted, time: .shortened) }
        if let minutes { result["minutes"] = String(minutes) }
        return result
    }
}

enum NotificationCopyRenderer {
    static let supportedPlaceholders = ["{activity}", "{purpose}", "{time}", "{minutes}"]

    static func render(_ text: String, context: NotificationCopyContext) -> String {
        context.values.reduce(text) { partial, entry in
            partial.replacingOccurrences(of: "{\(entry.key)}", with: entry.value)
        }
    }

    static func unresolvedPlaceholders(in text: String) -> [String] {
        var result: [String] = []
        var searchStart = text.startIndex
        while let open = text[searchStart...].firstIndex(of: "{") {
            guard let close = text[open...].firstIndex(of: "}") else { break }
            let token = String(text[open...close])
            if !supportedPlaceholders.contains(token), !result.contains(token) {
                result.append(token)
            }
            searchStart = text.index(after: close)
            if searchStart >= text.endIndex { break }
        }
        return result
    }
}

enum NotificationCopyResolver {
    static func resolve(
        id: NotificationTemplateID,
        moment: NightWatchNotificationMoment,
        context: NotificationCopyContext,
        overrides: [NotificationCopyOverride]
    ) -> NightWatchNotificationCopy {
        let defaults = NightWatchGuidance.notificationCopy(
            for: moment,
            activityTitle: context.activityTitle,
            tip: context.tip
        )
        guard id.isEditable,
              let override = overrides.first(where: { $0.id == id }) else {
            return defaults
        }
        return NightWatchNotificationCopy(
            title: NotificationCopyRenderer.render(override.title ?? defaults.title, context: context),
            body: NotificationCopyRenderer.render(override.body ?? defaults.body, context: context)
        )
    }
}

extension NotificationPreferences {
    var editableCopyOverrides: [NotificationCopyOverride] { copyOverrides }

    func copyOverride(for id: NotificationTemplateID) -> NotificationCopyOverride? {
        copyOverrides.first { $0.id == id }
    }

    mutating func setCopyOverride(_ override: NotificationCopyOverride) {
        copyOverrides.removeAll { $0.id == override.id }
        if !override.isEmpty { copyOverrides.append(override) }
        copyOverrides.sort { $0.id.rawValue < $1.id.rawValue }
    }

    mutating func resetCopy(for id: NotificationTemplateID) {
        copyOverrides.removeAll { $0.id == id }
    }

    mutating func resetAllCopies() {
        copyOverrides = []
    }
}
