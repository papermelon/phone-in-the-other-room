import XCTest

final class RewardEngineTests: XCTestCase {
    private let earnedAt = Date(timeIntervalSince1970: 2_000_000_000)

    func testFirstCompletionUsesWindDownBookendAndExcludesIndependentMorning() throws {
        let reward = try XCTUnwrap(
            RewardEngine().generateReward(
                for: completedNightWatch(),
                progress: .empty,
                earnedAt: earnedAt
            )
        )

        XCTAssertEqual(reward.type, .ribbon)
        XCTAssertEqual(reward.family, .nightMarker)
        XCTAssertEqual(reward.title, "First Wind Down")
        XCTAssertEqual(reward.context?.windDownMinutes, 30)
        XCTAssertEqual(reward.context?.morningQuietMinutes, 0)
        XCTAssertEqual(reward.context?.quietMinutes, 30)
        XCTAssertEqual(reward.context?.eveningActivity, .read)
        XCTAssertEqual(reward.context?.morningActivity, .openCurtains)
        XCTAssertEqual(reward.context?.protectedNightNumber, 1)
        XCTAssertEqual(reward.earnedAt, earnedAt)
    }

    func testKeepsakeFamiliesRotateWithoutUsingRarityOdds() throws {
        let run = completedNightWatch()
        let rewards = try [7, 8, 9].map { completedRuns in
            try XCTUnwrap(
                RewardEngine().generateReward(
                    for: run,
                    progress: progress(completedRuns: completedRuns),
                    earnedAt: earnedAt
                )
            )
        }

        XCTAssertEqual(rewards.map(\.family), [.pastureFind, .nightMarker, .ollieNote])
        XCTAssertEqual(rewards.map(\.rarity), [.common, .common, .common])
        XCTAssertEqual(Set(rewards.map(\.type)).count, 3)
    }

    func testWarningsMinutesAndStreakDoNotCreateAHighValueRewardTier() throws {
        var runWithWarnings = completedNightWatch(windDownMinutes: 15, morningQuietMinutes: 15)
        runWithWarnings.warningCount = 8
        var highStreakProgress = progress(completedRuns: 7)
        highStreakProgress.currentStreak = 40
        highStreakProgress.longestStreak = 40

        let longWindowReward = try XCTUnwrap(
            RewardEngine().generateReward(
                for: completedNightWatch(windDownMinutes: 60, morningQuietMinutes: 60),
                progress: progress(completedRuns: 7),
                earnedAt: earnedAt
            )
        )
        let warningReward = try XCTUnwrap(
            RewardEngine().generateReward(
                for: runWithWarnings,
                progress: highStreakProgress,
                earnedAt: earnedAt
            )
        )

        XCTAssertEqual(longWindowReward.type, warningReward.type)
        XCTAssertEqual(longWindowReward.rarity, warningReward.rarity)
        XCTAssertEqual(longWindowReward.title, warningReward.title)
        XCTAssertNotEqual(longWindowReward.context?.quietMinutes, warningReward.context?.quietMinutes)
    }

    func testMilestonesUseTotalProtectedNightsRatherThanCurrentStreak() throws {
        var existingProgress = progress(completedRuns: 2)
        existingProgress.currentStreak = 0

        let reward = try XCTUnwrap(
            RewardEngine().generateReward(
                for: completedNightWatch(),
                progress: existingProgress,
                earnedAt: earnedAt
            )
        )

        XCTAssertEqual(reward.type, .sheepBadge)
        XCTAssertEqual(reward.title, "Three Wind Downs")
        XCTAssertEqual(reward.context?.protectedNightNumber, 3)
    }

    func testEarlyEndKeepsakeIsAConsolationNotAProtectedNight() throws {
        var run = completedNightWatch()
        run.state = .endedEarly
        run.completedSuccessfully = false
        run.endedAt = run.startedAt.addingTimeInterval(10 * 60)

        let reward = try XCTUnwrap(
            RewardEngine().generateReward(
                for: run,
                progress: progress(completedRuns: 12),
                earnedAt: earnedAt
            )
        )

        XCTAssertEqual(reward.type, .muddyPaw)
        XCTAssertEqual(reward.family, .freshStart)
        XCTAssertEqual(reward.context?.protectedNightNumber, 0)
        XCTAssertEqual(reward.context?.windDownMinutes, 10)
        XCTAssertEqual(reward.context?.morningQuietMinutes, 0)
    }

    func testLegacyRewardDecodesWithoutContext() throws {
        let data = """
        {
          "id": "00000000-0000-0000-0000-000000000010",
          "type": "sheepBadge",
          "rarity": "uncommon",
          "title": "Sheep Badge",
          "description": "A badge for a calm night with Ollie.",
          "earnedAt": 1000,
          "runDurationMinutes": 30,
          "isDemoReward": false
        }
        """.data(using: .utf8)!

        let reward = try JSONDecoder().decode(RewardItem.self, from: data)

        XCTAssertNil(reward.context)
        XCTAssertEqual(reward.family, .nightMarker)
    }

    func testKeepsakeContextRoundTripsThroughJSON() throws {
        let reward = try XCTUnwrap(
            RewardEngine().generateReward(
                for: completedNightWatch(),
                progress: .empty,
                earnedAt: earnedAt
            )
        )

        let data = try JSONEncoder().encode(reward)
        let decoded = try JSONDecoder().decode(RewardItem.self, from: data)

        XCTAssertEqual(decoded, reward)
    }

    private func completedNightWatch(
        windDownMinutes: Int = 30,
        morningQuietMinutes: Int = 30
    ) -> FocusRun {
        let bedtime = Date(timeIntervalSince1970: 1_800_000_000)
        let startedAt = bedtime.addingTimeInterval(TimeInterval(-windDownMinutes * 60))
        let wakeTime = bedtime.addingTimeInterval(8 * 60 * 60)
        let protectedUntil = wakeTime.addingTimeInterval(TimeInterval(morningQuietMinutes * 60))
        let plan = NightWatchPlan(
            intendedBedtime: bedtime,
            wakeTime: wakeTime,
            protectedUntil: protectedUntil,
            windDownMinutes: windDownMinutes,
            morningQuietMinutes: morningQuietMinutes,
            eveningActivity: .read,
            morningActivity: .openCurtains
        )
        var run = FocusRun(
            plannedDurationSeconds: protectedUntil.timeIntervalSince(startedAt),
            startedAt: startedAt,
            state: .completed,
            guardKind: .honorTimer,
            nightWatchPlan: plan
        )
        run.completedSuccessfully = true
        run.endedAt = protectedUntil
        run.actualDurationSeconds = run.plannedDurationSeconds
        return run
    }

    private func progress(completedRuns: Int) -> UserProgress {
        UserProgress(
            totalCompletedRuns: completedRuns,
            totalFocusMinutes: completedRuns * 60,
            currentStreak: 0,
            longestStreak: 0,
            rewardsCollected: completedRuns,
            ollieLevel: 1
        )
    }
}
