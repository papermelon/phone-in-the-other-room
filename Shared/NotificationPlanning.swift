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
        now: Date = Date()
    ) -> [PlannedNotification] {
        let plannedStart = plan.intendedBedtime.addingTimeInterval(
            TimeInterval(-plan.windDownMinutes * 60)
        )
        let windDownStart = max(startedAt, plannedStart)
        var candidates: [PlannedNotification] = []

        for minutes in cadence.leadInMinutes {
            candidates.append(
                copy(
                    id: "night-watch-lead-in-\(minutes)",
                    date: windDownStart.addingTimeInterval(TimeInterval(-minutes * 60)),
                    phase: .windDown,
                    moment: .windDownLeadIn(minutes: minutes),
                    importance: .passive,
                    playsSound: false,
                    destination: .home
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
                importance: .active,
                playsSound: soundsEnabled,
                destination: .home
            )
        )

        if cadence.includesWindDownMidpoint {
            candidates.append(
                copy(
                    id: "night-watch-wind-down-midpoint",
                    date: midpoint(from: windDownStart, to: plan.intendedBedtime),
                    phase: .windDown,
                    moment: .windDownMidpoint,
                    activityTitle: plan.eveningActivity.shortTitle,
                    tip: educationalTipsEnabled
                        ? NightWatchGuidance.tip(for: .windDown, seed: seed)
                        : purpose.reminderPhrase,
                    importance: .passive,
                    playsSound: false,
                    destination: .activeRun
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
                destination: .activeRun
            )
        )
        candidates.append(
            copy(
                id: "night-watch-phone-free-morning",
                date: plan.wakeTime,
                phase: .morningQuiet,
                moment: .phoneFreeMorning,
                activityTitle: plan.morningActivity.shortTitle,
                tip: purpose.reminderPhrase,
                importance: .passive,
                playsSound: false,
                destination: .activeRun
            )
        )

        if cadence.includesMorningMidpoint {
            candidates.append(
                copy(
                    id: "night-watch-morning-midpoint",
                    date: midpoint(from: plan.wakeTime, to: plan.protectedUntil),
                    phase: .morningQuiet,
                    moment: .morningMidpoint,
                    activityTitle: plan.morningActivity.shortTitle,
                    importance: .passive,
                    playsSound: false,
                    destination: .activeRun
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
                destination: .nights
            )
        )

        return spaced(candidates.sorted { $0.date < $1.date })
            .filter { $0.date > now }
    }

    static func usageNotification(
        for phase: NightWatchPhase,
        date: Date = Date()
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
            destination: .activeRun
        )
    }

    static func reflectionNotification(
        at date: Date,
        now: Date = Date()
    ) -> PlannedNotification? {
        guard date > now else { return nil }
        return copy(
            id: "night-watch-morning-reflection",
            date: date,
            phase: .complete,
            moment: .morningReflection,
            importance: .passive,
            playsSound: false,
            destination: .morningReflection
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
        importance: NotificationImportance,
        playsSound: Bool,
        destination: NotificationDestination
    ) -> PlannedNotification {
        let copy = NightWatchGuidance.notificationCopy(
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
