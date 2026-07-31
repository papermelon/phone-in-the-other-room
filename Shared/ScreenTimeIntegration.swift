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
