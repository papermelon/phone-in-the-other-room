#if DEBUG
import Foundation

@MainActor
enum ScreenbookFixtures {
    static let suiteName = "com.ngawangchime.countingsheep.screenbook-fixtures"
    static let timeZone = TimeZone(identifier: "Asia/Singapore") ?? .gmt

    static func now(for kind: ScreenbookScenarioKind?) -> Date {
        switch kind {
        case .activeWindDown: return date(hour: 22, minute: 15)
        case .earlyEnd: return date(hour: 22, minute: 20)
        case .configuredHome: return date(hour: 22, minute: 40)
        case .interactiveHome: return date(hour: 20, minute: 0)
        default: return date(hour: 20, minute: 0)
        }
    }

    static func makeViewModel(for kind: ScreenbookScenarioKind?) -> FocusRunViewModel {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("Could not create the isolated Screenbook defaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        let persistence = PersistenceService(defaults: defaults)
        let fixedNow = now(for: kind)

        if kind != .onboardingWelcome {
            persistence.nightWatchPreferences = configuredPreferences
            persistence.windDownSchedule = schedule(for: kind)
            persistence.offlinePurpose = OfflinePurposeProfile(category: .read)
            persistence.orientationState = CountingSheepOrientationState(
                status: .completed,
                seenContextualTips: Set(CountingSheepContextualTip.allCases)
            )
            persistence.progress = progress
            persistence.sheepSearchState = searchState
            persistence.farmState = farmState
        }

        let liveActivity = FocusRunLiveActivityService(
            installationID: uuid(990),
            enabled: true
        )
        let coordinator = FocusSessionCoordinator(
            persistence: persistence,
            liveActivity: liveActivity,
            watch: .inactiveForDeterministicCapture(),
            notificationEffectsEnabled: false
        )
        let social = NightFlockViewModel(
            featureEnabled: true,
            previewPhase: .ready,
            previewAccountState: .linked
        )
        let viewModel = FocusRunViewModel(
            coordinator: coordinator,
            persistence: persistence,
            nowProvider: { fixedNow },
            startsExternalServices: false,
            nightFlockViewModel: social
        )
        viewModel.enableScreenbookStartReadiness()

        if kind == .configuredHome || kind == .interactiveHome {
            // Social presentation deliberately uses its actual observation
            // clock. The fixed Phone Away clock is for navigation only; using
            // it here would make a live status look expired in a real capture.
            social.installV4ObservedPartyPreview(homeSlumberParty(at: Date()))
        } else if kind == .slumberPartyNoRound {
            social.installV4ObservedPartyPreview(membershipSlumberParty(at: Date(), round: nil))
        } else if kind == .slumberPartyBetweenRounds {
            social.installV4ObservedPartyPreview(membershipSlumberParty(at: Date(), round: .completed))
        } else if kind == .slumberPartySharedHabitsSummary || kind == .slumberPartySharedHabitsConsent {
            let fixture = sharedHabitsParty(
                at: fixedNow,
                hasAgreement: kind == .slumberPartySharedHabitsSummary
            )
            social.installV4ObservedPartyPreview(fixture.detail)
            social.v4ListState = NightFlockV4ListStateResponse(
                parties: [fixture.detail.summary],
                sharedHabitsVersion: 1
            )
            social.sharedHabitsStates[fixture.detail.summary.partyID] = fixture.state
        }

        switch kind {
        case .activeWindDown:
            // Exercise the production admission/start path so this fixture
            // also materializes the ordinary morning that Home must route
            // behind the live Wind Down. The fixture still disables external
            // protection/Live Activity effects for deterministic rendering.
            let template = activeRun(state: .running, endedAt: nil)
            let result = coordinator.start(
                configuration: FocusRunConfiguration(
                    nightWatchPlan: template.nightWatchPlan!,
                    guardKind: .honorTimer
                ),
                focusAccepted: false,
                startedAt: template.startedAt,
                autoConfirmPlacement: true,
                appShieldingRequested: false,
                liveActivityRequested: false,
                runID: template.id
            )
            guard case .started = result else {
                preconditionFailure("Screenbook active Wind Down failed production start admission")
            }
            coordinator.reconcileSession(at: fixedNow)
        case .earlyEnd:
            var run = activeRun(state: .endedEarly, endedAt: fixedNow)
            run.actualDurationSeconds = 20 * 60
            run.completedSuccessfully = false
            run.endedEarlyReason = .userEnded
            coordinator.run = run
        case .activePhoneAway:
            let template = phoneAwayRun()
            let result = coordinator.start(
                configuration: FocusRunConfiguration(
                    nightWatchPlan: template.nightWatchPlan!,
                    guardKind: .honorTimer
                ),
                focusAccepted: false,
                startedAt: template.startedAt,
                autoConfirmPlacement: true,
                appShieldingRequested: false,
                liveActivityRequested: false,
                runID: template.id
            )
            guard case .started = result else {
                preconditionFailure("Screenbook active Phone Away failed production start admission")
            }
        default:
            break
        }
        return viewModel
    }

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_SG")
        calendar.timeZone = timeZone
        return calendar
    }

    private static var configuredPreferences: NightWatchPreferences {
        NightWatchPreferences(
            bedtimeHour: 23,
            bedtimeMinute: 0,
            wakeHour: 7,
            wakeMinute: 0,
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains,
            guardKind: .honorTimer,
            isConfigured: true,
            automaticStartEnabled: false
        )
    }

    private static func schedule(for kind: ScreenbookScenarioKind?) -> WindDownScheduleState {
        let primary = WindDownRoutine.primary(from: configuredPreferences, id: uuid(710))
        guard kind == .interactiveHome else {
            return WindDownScheduleState(routines: [primary])
        }
        return WindDownScheduleState(
            oneTimePeriods: [WindDownOneTimePeriod(
                id: uuid(711),
                title: "After dinner",
                role: .additionalQuiet,
                interval: DateInterval(start: date(hour: 19, minute: 55), end: date(hour: 20, minute: 30))
            )],
            routines: [primary]
        )
    }

    private static func homeSlumberParty(at now: Date) -> NightFlockV4PartyDetail {
        let partyID = uuid(720)
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let round = NightFlockV4Round(
            roundID: uuid(721), number: 1, timeZoneIdentifier: timeZone.identifier,
            startsOn: NightFlockLocalDate(
                year: components.year ?? 2026,
                month: components.month ?? 8,
                day: components.day ?? 11
            ),
            status: .active
        )
        let clover = NightFlockV4Membership(
            memberID: uuid(722), profile: CountingSheepUserProfile(displayName: "Clover"),
            role: .host, joinedAt: now.addingTimeInterval(-86_400)
        )
        let moss = NightFlockV4Membership(
            memberID: uuid(723), profile: CountingSheepUserProfile(displayName: "Moss"),
            role: .member, joinedAt: now.addingTimeInterval(-86_400)
        )
        let summary = NightFlockV4PartySummary(
            partyID: partyID, name: "Moonlit neighbours", memberCount: 2,
            myRole: .host, currentRound: round, revision: 1
        )
        let activity = NightFlockV4Activity(
            activityID: uuid(724), partyID: partyID, roundID: round.roundID,
            memberID: clover.memberID, day: 1, kind: .windDown,
            status: .completed, roundedMinutes: 30, occurredAt: now.addingTimeInterval(-1_800)
        )
        return NightFlockV4PartyDetail(
            summary: summary, myMemberID: clover.memberID, memberships: [clover, moss], activities: [activity],
            liveStatuses: [NightFlockV4LiveStatus(
                partyID: partyID, roundID: round.roundID, memberID: moss.memberID,
                status: .phoneAwayActive, revision: 1, observedAt: now,
                expiresAt: now.addingTimeInterval(15 * 60)
            )]
        )
    }

    /// Synthetic transport only: the production Home section renders this
    /// canonical membership-capable detail without a server round.
    private static func membershipSlumberParty(at now: Date, round status: NightFlockV4RoundStatus?) -> NightFlockV4PartyDetail {
        let partyID = uuid(status == nil ? 740 : 750)
        let clover = NightFlockV4Membership(memberID: uuid(status == nil ? 741 : 751), profile: .init(displayName: "Clover"), role: .host, joinedAt: now.addingTimeInterval(-86_400))
        let moss = NightFlockV4Membership(memberID: uuid(status == nil ? 742 : 752), profile: .init(displayName: "Moss"), role: .member, joinedAt: now.addingTimeInterval(-86_400))
        let round = status.map { NightFlockV4Round(roundID: uuid(753), number: 1, timeZoneIdentifier: timeZone.identifier, startsOn: .init(year: 2026, month: 8, day: 11), status: $0) }
        let activities = (0..<10).map { offset in
            NightFlockV4SharedActivity(
                activityID: uuid((status == nil ? 743 : 754) + offset),
                partyID: partyID,
                memberID: offset == 0 ? clover.memberID : moss.memberID,
                roundID: round?.roundID,
                day: round == nil ? nil : 7,
                kind: offset.isMultiple(of: 2) ? .phoneAway : .windDown,
                status: offset == 0 ? .partlyCompleted : .completed,
                roundedMinutes: max(5, 30 - offset),
                occurredAt: now.addingTimeInterval(TimeInterval(-1_200 - offset * 300)),
                roundActivityID: status == nil || offset != 1 ? nil : uuid(770),
                mySourceEventID: offset == 0 ? uuid(760) : nil
            )
        }
        let legacyBackfill: [NightFlockV4Activity] = status == nil ? [] : [
            .init(activityID: uuid(770), partyID: partyID, roundID: round!.roundID, memberID: moss.memberID, day: 7, kind: .windDown, status: .completed, roundedMinutes: 29, occurredAt: now.addingTimeInterval(-1_500)),
            .init(activityID: uuid(771), partyID: partyID, roundID: round!.roundID, memberID: clover.memberID, day: 6, kind: .phoneAway, status: .partlyCompleted, roundedMinutes: 15, occurredAt: now.addingTimeInterval(-1_800))
        ]
        return NightFlockV4PartyDetail(
            summary: .init(partyID: partyID, name: status == nil ? "Porch lights" : "Moonlit neighbours", memberCount: 2, myRole: .host, currentRound: round, revision: 1, sharingScope: .membership),
            myMemberID: clover.memberID,
            memberships: [clover, moss],
            activities: legacyBackfill,
            sharedActivities: activities,
            sharedLiveStatuses: [.init(statusID: uuid(status == nil ? 744 : 755), partyID: partyID, memberID: moss.memberID, roundID: round?.roundID, status: .phoneAwayActive, revision: 1, observedAt: now, expiresAt: now.addingTimeInterval(15 * 60))],
            sharedCheers: [.init(activityID: activities[0].activityID, cheer: .warmWave, count: 2, sentByMe: false)]
        )
    }

    private static func sharedHabitsParty(
        at now: Date,
        hasAgreement: Bool
    ) -> (detail: NightFlockV4PartyDetail, state: NightFlockSharedHabitsStateResponse) {
        let partyID = uuid(hasAgreement ? 780 : 790)
        let clover = NightFlockV4Membership(
            memberID: uuid(hasAgreement ? 781 : 791),
            profile: CountingSheepUserProfile(displayName: "Clover"),
            role: .host,
            joinedAt: now.addingTimeInterval(-172_800)
        )
        let moss = NightFlockV4Membership(
            memberID: uuid(hasAgreement ? 782 : 792),
            profile: CountingSheepUserProfile(displayName: "Moss"),
            role: .member,
            joinedAt: now.addingTimeInterval(-172_800)
        )
        let summary = NightFlockV4PartySummary(
            partyID: partyID, name: "Porch lights", memberCount: 2,
            myRole: .host, currentRound: nil, revision: 1, sharingScope: .membership
        )
        let detail = NightFlockV4PartyDetail(
            summary: summary, myMemberID: clover.memberID,
            memberships: [clover, moss], sharedActivities: []
        )
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let ending = NightFlockLocalDate(
            year: components.year ?? 2026,
            month: components.month ?? 8,
            day: components.day ?? 29
        )
        let records: [NightFlockSharedHabitRecord] = hasAgreement ? [
            NightFlockSharedHabitRecord(
                recordID: uuid(783), partyID: partyID, memberID: moss.memberID,
                sourceID: nil, revision: 2, kind: .sleep, localDate: ending,
                timeZoneIdentifier: timeZone.identifier, minutes: 425,
                outcome: nil, protectionMinutes: nil, evidence: .none,
                profileSnapshot: .init(displayName: "Moss", avatarID: "ollie"),
                isFormerMember: false, migratedAt: nil
            ),
            NightFlockSharedHabitRecord(
                recordID: uuid(784), partyID: partyID, memberID: uuid(785),
                sourceID: nil, revision: 1, kind: .phoneAway, localDate: ending,
                timeZoneIdentifier: timeZone.identifier, minutes: 35,
                outcome: .partlyCompleted, protectionMinutes: nil, evidence: .none,
                profileSnapshot: .init(displayName: "Fern", avatarID: "shepherd"),
                isFormerMember: true, migratedAt: now.addingTimeInterval(-86_400)
            )
        ] : []
        let periods: [NightFlockSharedHabitPeriodSummary] = hasAgreement ? [
            .init(memberID: moss.memberID, kind: .sleep, period: .lastNight, endingOn: ending, availableNights: 1, coveredNights: 1, averageMinutes: 425, method: "eligibleMean"),
            .init(memberID: moss.memberID, kind: .sleep, period: .last7Nights, endingOn: ending, availableNights: 7, coveredNights: 4, averageMinutes: 412.5, method: "eligibleMean"),
            .init(memberID: moss.memberID, kind: .sleep, period: .last30Nights, endingOn: ending, availableNights: 30, coveredNights: 16, averageMinutes: 405, method: "eligibleMean"),
            .init(memberID: moss.memberID, kind: .windDown, period: .lastNight, endingOn: ending, availableNights: 1, coveredNights: 1, averageMinutes: 30, method: "eligibleMean"),
            .init(memberID: moss.memberID, kind: .phoneAway, period: .last7Nights, endingOn: ending, availableNights: 7, coveredNights: 2, averageMinutes: 25, method: "eligibleMean")
        ] : []
        let agreement = hasAgreement ? NightFlockSharedHabitsAgreementReceipt(
            agreementID: uuid(786), memberEpochID: uuid(787),
            acceptedAt: now.addingTimeInterval(-86_400),
            timeZoneIdentifier: timeZone.identifier,
            firstEligibleSleepNight: ending
        ) : nil
        return (
            detail,
            NightFlockSharedHabitsStateResponse(
                agreement: agreement, records: records, nextCursor: nil,
                snapshotRevision: 1, periods: periods
            )
        )
    }

    private static var progress: UserProgress {
        UserProgress(
            totalCompletedRuns: 8,
            totalFocusMinutes: 465,
            currentStreak: 3,
            longestStreak: 5,
            rewardsCollected: 8,
            ollieLevel: 3,
            dailyFocusRecords: [
                DailyFocusRecord(day: date(day: 10, hour: 7), completedFocusMinutes: 60, successfulRuns: 1, rewardsEarned: 1, calendar: calendar),
                DailyFocusRecord(day: date(day: 9, hour: 7), completedFocusMinutes: 55, successfulRuns: 1, rewardsEarned: 1, calendar: calendar)
            ],
            sheepBalance: 6,
            totalSheepEarned: 6
        )
    }

    private static var searchState: SheepSearchState {
        var state = SheepSearchState.empty
        for (index, definition) in SheepCatalog.all.prefix(6).enumerated() {
            state.append(SheepSearchOutcome(
                id: uuid(index + 1),
                runID: uuid(index + 101),
                protectedNightNumber: index + 1,
                result: .found,
                sheepID: definition.id,
                rarity: definition.rarity,
                habitat: definition.habitat,
                trailStrength: 62 + index,
                encounterOdds: index < 3 ? 1 : 0.62,
                trailDistance: Double(index + 3),
                consecutiveNoFinds: 0,
                bonusPoints: 0,
                createdAt: date(day: 4 + index, hour: 7)
            ))
        }
        state.trailMap.credit(runID: uuid(900), minutes: 30)
        return state
    }

    private static var farmState: FarmState {
        var state = FarmMigration.migrated(existing: nil, searchState: searchState)
        state.woolBalance = 34
        if !state.sheep.isEmpty { state.sheep[0].isFavorite = true }
        if state.sheep.count > 1 { state.sheep[1].lastShearedProtectedNight = 5 }
        state.ownedShopItemIDs = ["farm_lanterns", "ollie_moss_bandana"]
        // Equipped pasture decorations can briefly inherit TabView's pre-layout geometry.
        // Keep the capture fixed while still representing an owned Farm cosmetic.
        state.equipment.ollieAccessoryItemID = "ollie_moss_bandana"
        return state
    }

    private static func activeRun(state: FocusRunState, endedAt: Date?) -> FocusRun {
        let start = date(hour: 22, minute: 0)
        let bedtime = date(hour: 23, minute: 0)
        let wake = date(day: 12, hour: 7, minute: 0)
        let protectedUntil = date(day: 12, hour: 7, minute: 30)
        let plan = NightWatchPlan(
            intendedBedtime: bedtime,
            wakeTime: wake,
            protectedUntil: protectedUntil,
            windDownMinutes: 30,
            morningQuietMinutes: 30,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        var run = FocusRun(
            id: uuid(700),
            plannedDurationSeconds: protectedUntil.timeIntervalSince(start),
            startedAt: start,
            state: state,
            guardKind: .honorTimer,
            nightWatchPlan: plan,
            appShieldingRequested: false,
            liveActivityRequested: false
        )
        run.phoneAwayValidatedAt = start
        run.endedAt = endedAt
        return run
    }

    private static func phoneAwayRun() -> FocusRun {
        let start = date(hour: 19, minute: 55)
        let end = date(hour: 20, minute: 25)
        return FocusRun(
            id: uuid(701),
            plannedDurationSeconds: end.timeIntervalSince(start),
            startedAt: start,
            state: .running,
            guardKind: .honorTimer,
            nightWatchPlan: .additionalQuiet(start: start, end: end),
            appShieldingRequested: false,
            liveActivityRequested: false
        )
    }

    private static func date(day: Int = 11, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: 2026,
            month: 8,
            day: day,
            hour: hour,
            minute: minute
        )) ?? Date(timeIntervalSince1970: 1_786_464_000)
    }

    private static func uuid(_ suffix: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", suffix))
            ?? UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
    }
}
#endif
