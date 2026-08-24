import Foundation

enum ScreenTimeSharedStorage {
    static let appGroupIdentifier = "group.com.ngawangchime.countingsheep"
    static let selectionKeyPrefix = "ollie.screenTime.selection."
    static let legacySelectionKeyPrefix = "phoneOther.screenTime.selection."

    static func selectionKey(for scope: ScreenTimeSelectionScope) -> String {
        selectionKeyPrefix + scope.rawValue
    }

    static func legacySelectionKey(for scope: ScreenTimeSelectionScope) -> String {
        legacySelectionKeyPrefix + scope.rawValue
    }
}

struct ScreenTimeReportPreferences: Codable, Equatable {
    enum Window: CaseIterable {
        case evening
        case morning
    }

    var eveningStartMinute: Int
    var eveningEndMinute: Int
    var morningStartMinute: Int
    var morningEndMinute: Int

    init(
        eveningStartMinute: Int,
        eveningEndMinute: Int,
        morningStartMinute: Int,
        morningEndMinute: Int
    ) {
        self.eveningStartMinute = Self.normalized(eveningStartMinute)
        self.eveningEndMinute = Self.normalized(eveningEndMinute)
        self.morningStartMinute = Self.normalized(morningStartMinute)
        self.morningEndMinute = Self.normalized(morningEndMinute)
    }

    static func defaults(for quietTime: NightWatchPreferences) -> Self {
        Self(
            eveningStartMinute: quietTime.bedtimeHour * 60 + quietTime.bedtimeMinute - 180,
            eveningEndMinute: quietTime.bedtimeHour * 60 + quietTime.bedtimeMinute,
            morningStartMinute: quietTime.wakeHour * 60 + quietTime.wakeMinute,
            morningEndMinute: quietTime.wakeHour * 60 + quietTime.wakeMinute
                + quietTime.morningQuietMinutes
        )
    }

    func minute(for window: Window, isStart: Bool) -> Int {
        switch (window, isStart) {
        case (.evening, true): return eveningStartMinute
        case (.evening, false): return eveningEndMinute
        case (.morning, true): return morningStartMinute
        case (.morning, false): return morningEndMinute
        }
    }

    mutating func setMinute(_ minute: Int, for window: Window, isStart: Bool) {
        let minute = Self.normalized(minute)
        switch (window, isStart) {
        case (.evening, true): eveningStartMinute = minute
        case (.evening, false): eveningEndMinute = minute
        case (.morning, true): morningStartMinute = minute
        case (.morning, false): morningEndMinute = minute
        }
    }

    func latestInterval(
        for window: Window,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> DateInterval {
        let startMinute = minute(for: window, isStart: true)
        let endMinute = minute(for: window, isStart: false)
        let startComponents = DateComponents(
            hour: startMinute / 60,
            minute: startMinute % 60,
            second: 0
        )
        let start = calendar.nextDate(
            after: now.addingTimeInterval(1),
            matching: startComponents,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .backward
        ) ?? now
        let endDayOffset = endMinute < startMinute ? 1 : 0
        let startOfDay = calendar.startOfDay(for: start)
        let endDay = calendar.date(
            byAdding: .day,
            value: endDayOffset,
            to: startOfDay
        ) ?? startOfDay
        let end = calendar.date(
            bySettingHour: endMinute / 60,
            minute: endMinute % 60,
            second: 0,
            of: endDay
        ) ?? start.addingTimeInterval(60)
        return DateInterval(start: start, end: max(end, start.addingTimeInterval(60)))
    }

    private static func normalized(_ minute: Int) -> Int {
        let minutesPerDay = 24 * 60
        return ((minute % minutesPerDay) + minutesPerDay) % minutesPerDay
    }
}

enum ScreenTimeSelectionScope: String, CaseIterable, Identifiable {
    case distracting
    case productive
    case bedtime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .distracting: return "Screen Time"
        case .productive: return "Work & learning (legacy)"
        case .bedtime: return "Late Screen Time"
        }
    }

    var pickerTitle: String {
        switch self {
        case .distracting: return "Choose distracting apps"
        case .productive: return "Choose work or learning apps"
        case .bedtime: return "Choose bedtime apps"
        }
    }

    var detail: String {
        switch self {
        case .distracting:
            return "Apps and categories to count as avoidable screen time. Websites shown by Apple are ignored."
        case .productive:
            return "A legacy analytics scope kept for compatibility; it is not part of Wind Down."
        case .bedtime:
            return "Apps and categories to watch during the wind-down window. Websites shown by Apple are ignored."
        }
    }
}

/// The small set of states the app needs to explain before it promises an app shield.
/// Keeping this independent of FamilyControls makes the start preflight testable on every
/// target, including the watch and unit-test bundle.
enum ShieldingReadiness: Equatable {
    case ready
    case authorizationRequired
    case denied
    case revoked
    case noSelection
    case unavailable
    case runtimeFailure

    var title: String {
        switch self {
        case .ready: return "App protection is ready"
        case .authorizationRequired, .denied, .revoked, .noSelection, .unavailable, .runtimeFailure:
            return "Set up app protection"
        }
    }

    var detail: String {
        switch self {
        case .ready: return "Your chosen apps and categories will pause during protected time. Counting Sheep stays available."
        case .authorizationRequired: return "Allow Screen Time access, then choose at least one app or category to continue."
        case .denied: return "Screen Time access is off. Restore it and choose at least one app or category to continue."
        case .revoked: return "Screen Time access changed. Restore it and review your selected apps or categories before another start."
        case .noSelection: return "Choose at least one app or category to continue. Counting Sheep cannot verify the names you chose."
        case .unavailable: return "This device cannot set up app protection right now."
        case .runtimeFailure: return "App protection did not stay active. This run remains factual; repair protection before another start."
        }
    }

    var canStartProtectedSession: Bool { self == .ready }
}

enum ScreenTimeSelectionSelfConfirmation: Equatable {
    case needsSelection
    case needsConfirmation(appCount: Int, categoryCount: Int)
    case confirmed(appCount: Int, categoryCount: Int)

    var prompt: String {
        switch self {
        case .needsSelection: return "Choose at least one app or category in Apple’s picker."
        case .needsConfirmation, .confirmed:
            return "Does this include the apps that pull you back most often?"
        }
    }
}

enum ScreenTimeSelectionPresentation {
    static func confirmation(
        appCount: Int,
        categoryCount: Int,
        userConfirmed: Bool
    ) -> ScreenTimeSelectionSelfConfirmation {
        guard appCount + categoryCount > 0 else { return .needsSelection }
        return userConfirmed
            ? .confirmed(appCount: appCount, categoryCount: categoryCount)
            : .needsConfirmation(appCount: appCount, categoryCount: categoryCount)
    }
}

/// The picker is intentionally opaque. This policy never accepts a named app
/// claim and makes every new session share the same protection prerequisite.
enum ScreenTimeProtectionStartPolicy {
    static func canStart(_ readiness: ShieldingReadiness) -> Bool {
        readiness.canStartProtectedSession
    }
}

/// An early-wake choice first crosses the existing Wind Down terminal
/// authorization boundary. Only choices that create a new protected Morning
/// window need current protection readiness; skipping never strands someone
/// behind a revoked Family Controls selection.
enum EarlyWakeProtectionStartPolicy {
    static func requiresReadiness(for intent: MorningQuietIntent) -> Bool {
        switch intent {
        case .startNow, .deferToUsualTime:
            return true
        case .skipToday, .keepWindDownRunning:
            return false
        }
    }

    static func canCommit(intent: MorningQuietIntent, readiness: ShieldingReadiness) -> Bool {
        !requiresReadiness(for: intent) || readiness.canStartProtectedSession
    }
}

/// Home does not offer a timer-only alternative when the shared protection
/// prerequisite needs repair. This remains pure so shortcuts, schedules, and
/// the SwiftUI shell can present the same honest next action.
enum HomeProtectionStartPresentation: Equatable {
    case ready(selectionSummary: String)
    case repair(title: String, detail: String)

    static func resolve(
        readiness: ShieldingReadiness,
        selectionSummary: String
    ) -> Self {
        guard readiness == .ready else {
            let title = readiness == .noSelection
                ? "Choose apps to pause"
                : "Set up app protection"
            return .repair(title: title, detail: readiness.detail)
        }
        return .ready(selectionSummary: selectionSummary)
    }
}

/// Automatic scheduling must never create a protected run from a stale
/// authorization or selection. A repair state is a presentation outcome, not
/// evidence that the shield applied.
enum AutomaticWindDownProtectionDecision: Equatable {
    case schedule
    case needsRepair(ShieldingReadiness)

    static func resolve(readiness: ShieldingReadiness) -> Self {
        readiness.canStartProtectedSession ? .schedule : .needsRepair(readiness)
    }
}

#if SCREEN_TIME_REPORTS && canImport(DeviceActivity)
import DeviceActivity
import SwiftUI

extension DeviceActivityReport.Context {
    static let phoneOtherToday = Self("phone-other.today")
    static let phoneOtherWeekly = Self("phone-other.weekly")
    static let phoneOtherLateNight = Self("phone-other.late-night")
    static let phoneOtherWindDown = Self("phone-other.wind-down")
    static let phoneOtherMorningQuiet = Self("phone-other.morning-quiet")
}
#endif
