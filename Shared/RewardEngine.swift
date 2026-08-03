import Foundation

struct RewardEngine {
    func generateReward(
        for run: FocusRun,
        progress: UserProgress,
        demoMode: Bool = false,
        earnedAt: Date = Date()
    ) -> RewardItem? {
        guard run.isProgressionEligibleNightWatch || !run.isNightWatch else { return nil }
        guard run.completedSuccessfully else {
            return consolation(for: run, earnedAt: earnedAt)
        }

        let minutes = run.creditedQuietMinutes
        if demoMode {
            return RewardItem(
                id: UUID(),
                type: .ollieMail,
                rarity: .demo,
                title: "Ollie Mail",
                description: "A small note from Ollie's practice Wind Down.",
                earnedAt: earnedAt,
                runDurationMinutes: minutes,
                isDemoReward: true,
                context: rewardContext(for: run, protectedNightNumber: progress.totalCompletedRuns + 1)
            )
        }

        let protectedNightNumber = progress.totalCompletedRuns + 1
        let context = rewardContext(for: run, protectedNightNumber: protectedNightNumber)
        let type: RewardType
        let rarity: RewardRarity
        let rewardTitle: String

        if let milestone = milestone(for: protectedNightNumber) {
            type = milestone.type
            rarity = milestone.rarity
            rewardTitle = milestone.title
        } else {
            type = rotatingType(for: protectedNightNumber)
            rarity = .common
            rewardTitle = title(for: type)
        }

        return RewardItem(
            id: UUID(),
            type: type,
            rarity: rarity,
            title: rewardTitle,
            description: description(for: type),
            earnedAt: earnedAt,
            runDurationMinutes: minutes,
            isDemoReward: false,
            context: context
        )
    }

    func consolation(for run: FocusRun, earnedAt: Date = Date()) -> RewardItem? {
        guard run.isProgressionEligibleNightWatch || !run.isNightWatch else { return nil }
        guard run.state == .endedEarly else { return nil }
        let minutes = run.isNightWatch ? run.creditedQuietMinutes : max(0, Int(run.actualDurationSeconds / 60))
        return RewardItem(
            id: UUID(),
            type: .muddyPaw,
            rarity: .consolation,
            title: "Muddy Paw Print",
            description: "Ollie kept your place warm. The quiet you made still counts as practice.",
            earnedAt: earnedAt,
            runDurationMinutes: minutes,
            isDemoReward: false,
            context: rewardContext(for: run, protectedNightNumber: 0)
        )
    }

    func updatedProgress(after run: FocusRun, current: UserProgress, reward: RewardItem?) -> UserProgress {
        var progress = current
        if run.completedSuccessfully && (run.isProgressionEligibleNightWatch || !run.isNightWatch) {
            let minutes = run.creditedQuietMinutes
            progress.totalCompletedRuns += 1
            progress.totalFocusMinutes += minutes
            progress.currentStreak += 1
            progress.longestStreak = max(progress.longestStreak, progress.currentStreak)
            progress.recordCompletedRun(minutes: minutes, warnings: run.warningCount, rewardEarned: reward != nil, at: run.progressDate)
            progress.addFocusEconomy(forCompletedMinutes: minutes)
        }
        if reward != nil { progress.rewardsCollected += 1 }
        progress.ollieLevel = min(5, 1 + progress.totalCompletedRuns / 3)
        return progress
    }

    private func rewardContext(for run: FocusRun, protectedNightNumber: Int) -> RewardContext? {
        guard let plan = run.nightWatchPlan else { return nil }

        return RewardContext(
            windDownMinutes: run.creditedWindDownMinutes,
            morningQuietMinutes: run.creditedMorningQuietMinutes,
            eveningActivity: plan.eveningActivity,
            morningActivity: plan.morningActivity,
            protectedNightNumber: protectedNightNumber
        )
    }

    private func rotatingType(for protectedNightNumber: Int) -> RewardType {
        let noteTypes: [RewardType] = [.ollieMail, .letter, .postcard]
        let findTypes: [RewardType] = [.tennisBall, .stick, .fieldMap]
        let markerTypes: [RewardType] = [.ribbon, .sheepBadge]
        let families = [noteTypes, findTypes, markerTypes]
        let familyIndex = (max(1, protectedNightNumber) - 1) % families.count
        let familyVisit = (max(1, protectedNightNumber) - 1) / families.count
        let family = families[familyIndex]
        return family[familyVisit % family.count]
    }

    private func milestone(for protectedNightNumber: Int) -> (type: RewardType, rarity: RewardRarity, title: String)? {
        switch protectedNightNumber {
        case 1:
            return (.ribbon, .uncommon, "First Protected Night")
        case 3:
            return (.sheepBadge, .uncommon, "Three Protected Nights")
        case 7:
            return (.fieldMap, .rare, "Seven Protected Nights")
        case 14:
            return (.trophy, .rare, "Fourteen Protected Nights")
        case 30:
            return (.trophy, .legendary, "Thirty Protected Nights")
        case 50:
            return (.trophy, .legendary, "Fifty Protected Nights")
        case 100:
            return (.trophy, .legendary, "One Hundred Protected Nights")
        default:
            return nil
        }
    }

    private func title(for type: RewardType) -> String {
        switch type {
        case .ollieMail: return "Ollie Mail"
        case .letter: return "Wind Down Letter"
        case .ribbon: return "Wind Down Ribbon"
        case .trophy: return "Barn-Shelf Trophy"
        case .tennisBall: return "Tiny Tennis Ball"
        case .stick: return "Perfect Stick"
        case .postcard: return "Postcard from the Other Room"
        case .sheepBadge: return "Sheep Badge"
        case .fieldMap: return "Deep Field Map"
        case .muddyPaw: return "Muddy Paw Print"
        }
    }

    private func description(for type: RewardType) -> String {
        switch type {
        case .ollieMail: return "A note Ollie carried back after Wind Down."
        case .letter: return "A little letter guarded until the phone woke."
        case .ribbon: return "A ribbon for keeping both edges of the night quiet."
        case .trophy: return "A tiny marker for protected nights gathered over time."
        case .tennisBall: return "A bright ball from the quiet side of the pasture."
        case .stick: return "A good stick from the other room. Possibly the best stick."
        case .postcard: return "A postcard from the place where the phone slept."
        case .sheepBadge: return "A small badge for a phone-away night with Ollie."
        case .fieldMap: return "A map of the quiet path from wind-down to morning."
        case .muddyPaw: return "A soft reminder that shorter runs are allowed."
        }
    }
}
