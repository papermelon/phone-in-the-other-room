import Foundation

struct NightFlockAggregatePresentation: Equatable, Sendable {
    var title: String
    var detail: String

    static func nighttime(positiveCount: Int, memberCount: Int) -> Self {
        presentation(
            positiveCount: positiveCount,
            memberCount: memberCount,
            allTitle: "The whole flock has tucked in.",
            someTitle: "Someone in the flock has tucked in.",
            countTitle: { "\($0) phones are resting away." },
            emptyDetail: "Your group’s shared progress will appear here when someone chooses to share an update.",
            positiveDetail: "Named progress is shown only inside this invited group."
        )
    }

    static func morning(positiveCount: Int, memberCount: Int) -> Self {
        presentation(
            positiveCount: positiveCount,
            memberCount: memberCount,
            allTitle: "The whole flock kept the morning quiet.",
            someTitle: "A quiet morning reached the pasture.",
            countTitle: { "\($0) quiet mornings reached the pasture." },
            emptyDetail: "Your group’s morning progress will appear here when someone chooses to share an update.",
            positiveDetail: "No update shared is not counted as completion."
        )
    }

    private static func presentation(
        positiveCount: Int,
        memberCount: Int,
        allTitle: String,
        someTitle: String,
        countTitle: (Int) -> String,
        emptyDetail: String,
        positiveDetail: String
    ) -> Self {
        let count = max(0, min(positiveCount, memberCount))
        guard count > 0 else {
            return Self(title: "Your group is getting ready.", detail: emptyDetail)
        }
        if count == memberCount {
            return Self(title: allTitle, detail: positiveDetail)
        }
        if memberCount <= 3 {
            return Self(title: someTitle, detail: positiveDetail)
        }
        return Self(title: countTitle(count), detail: positiveDetail)
    }
}

enum NightFlockPrivacyPresentation {
    static func pastureEntries(
        _ entries: [NightFlockPastureEntry],
        memberCount: Int
    ) -> [NightFlockPastureEntry] {
        memberCount <= 3 ? Array(entries.prefix(1)) : entries
    }
}

struct NightFlockHomeSummary: Equatable, Sendable {
    var title: String
    var detail: String
    var challengeDay: Int?

    static let invitation = Self(
        title: "Choose a Wind Down goal together",
        detail: "Invite people you know, share what helps, and keep one another going for seven nights.",
        challengeDay: nil
    )

    static func make(from snapshot: NightFlockSnapshot, at date: Date = Date()) -> Self {
        let day = NightFlockChallengeDayRules.challengeDay(at: date, challenge: snapshot.challenge)
        if let goal = snapshot.challenge.sharedGoal {
            let detail: String
            if snapshot.challenge.status == .pending {
                detail = "Everyone can keep their own bedtime and routine while the lobby gets ready."
            } else if snapshot.challenge.status == .completed {
                detail = "Your invited group completed the seven-night Wind Down commitment."
            } else {
                detail = "Your group is following one shared Wind Down goal."
            }
            return Self(title: goal.title, detail: detail, challengeDay: day)
        }
        let summary = day.flatMap { value in snapshot.days.first(where: { $0.day == value }) }
        let presentation = NightFlockAggregatePresentation.nighttime(
            positiveCount: summary?.phoneTuckedCount ?? 0,
            memberCount: snapshot.members.count
        )
        return Self(title: presentation.title, detail: presentation.detail, challengeDay: day)
    }
}

struct NightFlockMemberBoardRow: Identifiable, Equatable, Sendable {
    var memberID: UUID
    var alias: String
    var ready: Bool
    var tonightStatus: NightFlockMemberNightStatus
    var qualifyingNights: Int
    var windDownMinutes: Int
    var phoneAwayMinutes: Int
    var shieldingTitle: String?
    var sleepMinutes: Int?
    var restfulnessTitle: String?
    var sharedRoutineTitles: [String]

    var id: UUID { memberID }
}

enum NightFlockMemberBoard {
    static func rows(
        from snapshot: NightFlockSnapshot,
        at date: Date = Date(),
        guidanceTitles: (String) -> String = { $0 }
    ) -> [NightFlockMemberBoardRow] {
        let day = NightFlockChallengeDayRules.challengeDay(at: date, challenge: snapshot.challenge)
        let tonight = day.flatMap { value in snapshot.days.first(where: { $0.day == value }) }
        return snapshot.members.map { member in
            let setup = snapshot.memberSetups.first(where: { $0.memberID == member.id })
            let sharing = setup?.sharing ?? NightFlockSharingPreferences(
                shareGoalProgress: setup?.sharingEnabled ?? true,
                shareRoutineIdeas: setup?.shareRoutineIdeas ?? false
            )
            let progress = snapshot.allMemberProgress.filter { $0.memberID == member.id }
            let tonightProgress = tonight?.memberProgress.first(where: { $0.memberID == member.id })
            let projectedTonight = tonightProgress.map {
                NightFlockProjectionRules.projectedProgress($0, sharing: sharing)
            }
            let routines = snapshot.sharedRoutineIdeas
                .filter { $0.memberID == member.id }
                .map { guidanceTitles($0.guidanceID) }
            return NightFlockMemberBoardRow(
                memberID: member.id,
                alias: member.alias,
                ready: setup?.goalAccepted == true && setup?.setupReady == true,
                tonightStatus: projectedTonight?.status ?? .privateNoUpdate,
                qualifyingNights: NightFlockRewardRules.qualifyingNightCount(
                    in: progress,
                    memberID: member.id
                ),
                windDownMinutes: progress.compactMap(\.windDownMinutes).reduce(0, +),
                phoneAwayMinutes: progress.compactMap(\.phoneAwayMinutes).reduce(0, +),
                shieldingTitle: sharing.shareShieldingStatus
                    ? projectedTonight?.shieldingEvidence.title
                    : nil,
                sleepMinutes: projectedTonight?.sleepDurationMinutes,
                restfulnessTitle: projectedTonight?.restfulness?.title,
                sharedRoutineTitles: sharing.shareRoutineIdeas ? routines : []
            )
        }
    }
}
