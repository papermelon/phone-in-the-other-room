import Foundation

enum NightWatchNotificationPlanBuilder {
    static let minimumMidpointSpacing: TimeInterval = 10 * 60

    static func scheduledNotifications(
        for plan: NightWatchPlan,
        startedAt: Date,
        cadence: NotificationCadence,
        purpose: OfflinePurposeProfile,
        seed: UUID,
        educationalTipsEnabled: Bool,
        soundsEnabled: Bool,
        copyOverrides: [NotificationCopyOverride] = [],
        now: Date = Date()
    ) -> [PlannedNotification] {
        let plannedStart = plan.intendedBedtime.addingTimeInterval(
            TimeInterval(-plan.windDownMinutes * 60)
        )
        let windDownStart = max(startedAt, plannedStart)
        var candidates: [PlannedNotification] = []

        if plan.role == .additionalQuiet {
            candidates.append(
                PlannedNotification(
                    id: "night-watch-quiet-period-start",
                    date: windDownStart,
                    title: "Phone Away is coming",
                    body: "A little room away from the screen starts at \(OllieFormat.time(windDownStart)).",
                    phase: .windDown,
                    importance: .active,
                    playsSound: soundsEnabled,
                    destination: .home
                )
            )
            candidates.append(
                copy(
                    id: "night-watch-quiet-period-complete",
                    date: plan.protectedUntil,
                    phase: .complete,
                    moment: .quietPeriodComplete,
                    importance: .active,
                    playsSound: soundsEnabled,
                    destination: .nights,
                    copyOverrides: copyOverrides
                )
            )
            return spaced(candidates.sorted { $0.date < $1.date })
                .filter { $0.date > now }
        }

        for minutes in cadence.leadInMinutes {
            candidates.append(
                copy(
                    id: "night-watch-lead-in-\(minutes)",
                    date: windDownStart.addingTimeInterval(TimeInterval(-minutes * 60)),
                    phase: .windDown,
                    moment: .windDownLeadIn(minutes: minutes),
                    importance: .passive,
                    playsSound: false,
                    destination: .home,
                    copyOverrides: copyOverrides
                )
            )
        }

        candidates.append(
            copy(
                id: "night-watch-wind-down-start",
                date: windDownStart,
                phase: .windDown,
                moment: .windDownReminder,
                tip: purpose.reminderPhrase,
                purposeText: purpose.reminderPhrase,
                importance: .active,
                playsSound: soundsEnabled,
                destination: .home,
                copyOverrides: copyOverrides
            )
        )

        if cadence.includesWindDownMidpoint {
            candidates.append(
                copy(
                    id: "night-watch-wind-down-midpoint",
                    date: midpoint(from: windDownStart, to: plan.intendedBedtime),
                    phase: .windDown,
                    moment: .windDownMidpoint,
                    activityTitle: plan.eveningNotificationActivityTitle(
                        allowsPersonalText: purpose.allowsCustomTextInNotifications
                    ),
                    tip: educationalTipsEnabled
                        ? NightWatchGuidance.tip(for: .windDown, seed: seed)
                        : purpose.reminderPhrase,
                    purposeText: purpose.reminderPhrase,
                    importance: .passive,
                    playsSound: false,
                    destination: .activeRun,
                    copyOverrides: copyOverrides
                )
            )
        }

        candidates.append(
            copy(
                id: "night-watch-sleep-time",
                date: plan.intendedBedtime,
                phase: .overnight,
                moment: .sleepTime,
                tip: cadence == .quiet && educationalTipsEnabled
                    ? NightWatchGuidance.tip(for: .windDown, seed: seed)
                    : nil,
                importance: .passive,
                playsSound: false,
                destination: .activeRun,
                copyOverrides: copyOverrides
            )
        )
        candidates.append(
            copy(
                id: "night-watch-phone-free-morning",
                date: plan.wakeTime,
                phase: .morningQuiet,
                moment: .phoneFreeMorning,
                activityTitle: plan.morningNotificationActivityTitle(
                    allowsPersonalText: purpose.allowsCustomTextInNotifications
                ),
                tip: purpose.reminderPhrase,
                purposeText: purpose.reminderPhrase,
                importance: .passive,
                playsSound: false,
                destination: .activeRun,
                copyOverrides: copyOverrides
            )
        )

        if cadence.includesMorningMidpoint {
            candidates.append(
                copy(
                    id: "night-watch-morning-midpoint",
                    date: midpoint(from: plan.wakeTime, to: plan.protectedUntil),
                    phase: .morningQuiet,
                    moment: .morningMidpoint,
                    activityTitle: plan.morningNotificationActivityTitle(
                        allowsPersonalText: purpose.allowsCustomTextInNotifications
                    ),
                    purposeText: purpose.reminderPhrase,
                    importance: .passive,
                    playsSound: false,
                    destination: .activeRun,
                    copyOverrides: copyOverrides
                )
            )
        }

        candidates.append(
            copy(
                id: "focus-run-complete",
                date: plan.protectedUntil,
                phase: .complete,
                moment: .complete,
                importance: .active,
                playsSound: soundsEnabled,
                destination: .nights,
                copyOverrides: copyOverrides
            )
        )

        return spaced(candidates.sorted { $0.date < $1.date })
            .filter { $0.date > now }
    }

    static func usageNotification(
        for phase: NightWatchPhase,
        date: Date = Date(),
        copyOverrides: [NotificationCopyOverride] = []
    ) -> PlannedNotification? {
        guard phase == .windDown || phase == .overnight || phase == .morningQuiet else {
            return nil
        }
        return copy(
            id: "night-watch-usage-\(phase.rawValue)",
            date: date,
            phase: phase,
            moment: .usageCue(phase),
            importance: .active,
            playsSound: false,
            destination: .activeRun,
            copyOverrides: copyOverrides
        )
    }

    static func reflectionNotification(
        at date: Date,
        now: Date = Date(),
        copyOverrides: [NotificationCopyOverride] = []
    ) -> PlannedNotification? {
        guard date > now else { return nil }
        return copy(
            id: "night-watch-morning-reflection",
            date: date,
            phase: .complete,
            moment: .morningReflection,
            importance: .passive,
            playsSound: false,
            destination: .morningReflection,
            copyOverrides: copyOverrides
        )
    }

    private static func midpoint(from start: Date, to end: Date) -> Date {
        start.addingTimeInterval(max(0, end.timeIntervalSince(start)) / 2)
    }

    private static func spaced(_ candidates: [PlannedNotification]) -> [PlannedNotification] {
        var result: [PlannedNotification] = []
        for candidate in candidates {
            guard result.last.map({
                candidate.date.timeIntervalSince($0.date) >= minimumMidpointSpacing
            }) ?? true else { continue }
            result.append(candidate)
        }
        return result
    }

    private static func copy(
        id: String,
        date: Date,
        phase: NightWatchPhase,
        moment: NightWatchNotificationMoment,
        activityTitle: String? = nil,
        tip: String? = nil,
        purposeText: String? = nil,
        importance: NotificationImportance,
        playsSound: Bool,
        destination: NotificationDestination,
        copyOverrides: [NotificationCopyOverride] = []
    ) -> PlannedNotification {
        let templateID = NotificationTemplateID.from(notificationID: id)
        let copy = templateID.map {
            NotificationCopyResolver.resolve(
                id: $0,
                moment: moment,
                context: NotificationCopyContext(
                    activityTitle: activityTitle,
                    purpose: purposeText ?? tip,
                    tip: tip,
                    date: date,
                    minutes: $0.minutes
                ),
                overrides: copyOverrides
            )
        } ?? NightWatchGuidance.notificationCopy(
            for: moment,
            activityTitle: activityTitle,
            tip: tip
        )
        return PlannedNotification(
            id: id,
            date: date,
            title: copy.title,
            body: copy.body,
            phase: phase,
            importance: importance,
            playsSound: playsSound,
            destination: destination
        )
    }
}

enum UpcomingWindDownNotificationPlanBuilder {
    static let maximumPendingCount = 64
    static let identifierPrefix = "upcoming-wind-down-"

    static func scheduledNotifications(
        for schedule: WindDownScheduleState,
        after date: Date,
        calendar: Calendar = .current,
        primaryExtensionMinutes: Int,
        purpose: OfflinePurposeProfile,
        copyOverrides: [NotificationCopyOverride] = [],
        limit: Int = maximumPendingCount
    ) -> [PlannedNotification] {
        schedule.upcomingPeriods(
            after: date,
            calendar: calendar,
            primaryExtensionMinutes: primaryExtensionMinutes,
            limit: limit
        ).map { period in
            let start = period.occurrence.interval.start
            let copy: NightWatchNotificationCopy
            if period.occurrence.role == .additionalQuiet {
                copy = NightWatchNotificationCopy(
                    title: "Phone Away is coming",
                    body: "A little room away from the screen starts at \(OllieFormat.time(start))."
                )
            } else {
                copy = NotificationCopyResolver.resolve(
                    id: .windDownStart,
                    moment: .windDownReminder,
                    context: NotificationCopyContext(
                        purpose: purpose.reminderPhrase,
                        tip: purpose.reminderPhrase,
                        date: start
                    ),
                    overrides: copyOverrides
                )
            }
            return PlannedNotification(
                id: identifier(for: period, date: start),
                date: start,
                title: copy.title,
                body: copy.body,
                phase: .windDown,
                importance: .active,
                playsSound: false,
                destination: .home
            )
        }
    }

    static func identifier(for period: WindDownSchedulePeriod, date: Date) -> String {
        "\(identifierPrefix)\(period.occurrence.routineID.uuidString)-\(Int(date.timeIntervalSince1970))"
    }
}
