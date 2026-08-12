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
            emptyDetail: "The pasture is quiet tonight.",
            positiveDetail: "Only shared tuck-ins appear here."
        )
    }

    static func morning(positiveCount: Int, memberCount: Int) -> Self {
        presentation(
            positiveCount: positiveCount,
            memberCount: memberCount,
            allTitle: "The whole flock kept the morning quiet.",
            someTitle: "A quiet morning reached the pasture.",
            countTitle: { "\($0) quiet mornings reached the pasture." },
            emptyDetail: "Morning notes will settle here gently.",
            positiveDetail: "No missed nights or private nights are shown."
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
            return Self(title: "Ollie is keeping watch.", detail: emptyDetail)
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
        title: "Night Flock",
        detail: "A small invite-only pasture for quiet nights.",
        challengeDay: nil
    )

    static func make(from snapshot: NightFlockSnapshot, at date: Date = Date()) -> Self {
        let day = NightFlockChallengeDayRules.challengeDay(at: date, challenge: snapshot.challenge)
        let summary = day.flatMap { value in snapshot.days.first(where: { $0.day == value }) }
        let presentation = NightFlockAggregatePresentation.nighttime(
            positiveCount: summary?.phoneTuckedCount ?? 0,
            memberCount: snapshot.members.count
        )
        return Self(title: presentation.title, detail: presentation.detail, challengeDay: day)
    }
}
