import Foundation

struct RewardEngine {
    func generateReward(for run: FocusRun, progress: UserProgress, demoMode: Bool = false) -> RewardItem? {
        guard run.completedSuccessfully else {
            return consolation(for: run)
        }

        let minutes = max(1, Int(run.plannedDurationSeconds / 60))
        if demoMode {
            return RewardItem(id: UUID(), type: .ollieMail, rarity: .demo, title: "Ollie Mail", description: "A note from the focus pasture.", earnedAt: Date(), runDurationMinutes: minutes, isDemoReward: true)
        }

        let rarity: RewardRarity
        if progress.currentStreak > 0 && progress.currentStreak % 5 == 0 {
            rarity = .legendary
        } else if minutes >= 45 {
            rarity = run.warningCount == 0 ? .rare : .uncommon
        } else if minutes >= 25 {
            rarity = run.warningCount == 0 ? .uncommon : .common
        } else {
            rarity = .common
        }

        let type: RewardType
        switch rarity {
        case .legendary: type = .trophy
        case .rare: type = .fieldMap
        case .uncommon: type = .sheepBadge
        default: type = [.ollieMail, .letter, .ribbon, .tennisBall, .postcard].randomElement() ?? .letter
        }

        return RewardItem(id: UUID(), type: type, rarity: rarity, title: title(for: type), description: description(for: type, rarity: rarity), earnedAt: Date(), runDurationMinutes: minutes, isDemoReward: false)
    }

    func consolation(for run: FocusRun) -> RewardItem? {
        guard run.state == .endedEarly else { return nil }
        let minutes = max(0, Int(run.actualDurationSeconds / 60))
        return RewardItem(id: UUID(), type: .muddyPaw, rarity: .consolation, title: "Muddy Paw Print", description: "Ollie came back early, but the trail still counts as practice.", earnedAt: Date(), runDurationMinutes: minutes, isDemoReward: false)
    }

    func updatedProgress(after run: FocusRun, current: UserProgress, reward: RewardItem?) -> UserProgress {
        var progress = current
        if run.completedSuccessfully {
            progress.totalCompletedRuns += 1
            progress.totalFocusMinutes += max(1, Int(run.plannedDurationSeconds / 60))
            progress.currentStreak += 1
            progress.longestStreak = max(progress.longestStreak, progress.currentStreak)
        }
        if reward != nil { progress.rewardsCollected += 1 }
        progress.ollieLevel = min(5, 1 + progress.totalCompletedRuns / 3)
        return progress
    }

    private func title(for type: RewardType) -> String {
        switch type {
        case .ollieMail: return "Ollie Mail"
        case .letter: return "Focus Letter"
        case .ribbon: return "First Run Ribbon"
        case .trophy: return "Focus Trophy"
        case .tennisBall: return "Tiny Tennis Ball"
        case .stick: return "Perfect Stick"
        case .postcard: return "Postcard from the Other Room"
        case .sheepBadge: return "Sheep Badge"
        case .fieldMap: return "Deep Field Map"
        case .muddyPaw: return "Muddy Paw Print"
        }
    }

    private func description(for type: RewardType, rarity: RewardRarity) -> String {
        switch type {
        case .ollieMail: return "A note from the focus pasture."
        case .letter: return "A crisp little letter Ollie guarded carefully."
        case .ribbon: return "A ribbon for making the first run feel real."
        case .trophy: return "A tiny trophy for a serious shepherding streak."
        case .tennisBall: return "A bright ball from the far side of the pasture."
        case .stick: return "A good stick. Possibly the best stick."
        case .postcard: return "A postcard proving the other room exists."
        case .sheepBadge: return "A badge for clean, steady focus."
        case .fieldMap: return "A map from deeper focus territory."
        case .muddyPaw: return "A soft reminder that shorter runs are allowed."
        }
    }
}
