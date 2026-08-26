import Foundation

enum CountingSheepOrientationStatus: String, Codable, Equatable {
    case notStarted
    case inProgress
    case dismissed
    case skipped
    case completed
}

enum CountingSheepOrientationStep: String, Codable, Equatable {
    case home
    case start
    case phoneAway
    case practiceOffer
    case practiceReward
    case farmMeetSheep
    case farmCapacity
    case farmWool
    case farmShear
    case farmCurrency
    case farmClaimWearable
    case farmEquipWearable
    case farmShop
    case farmSearch
    case slumberParty
    case settings
    case nights
    case completion
    /// Legacy three-step tour case. Decodes, then normalizes to `.phoneAway`.
    case navigation
    /// The fourth Home chapter tip. The old `.navigation` raw value remains
    /// reserved for legacy data and continues to normalize to `.phoneAway`.
    case rootTabs

    var normalized: Self { self == .navigation ? .phoneAway : self }

    var number: Int {
        if let chapter = FirstRunJourney.chapter(for: self) {
            return FirstRunJourney.number(for: self, chapter: chapter)
        }
        return FirstRunJourney.number(for: self, context: .defaults)
    }

    static let count = FirstRunJourney.count(for: .homeBasics)
}

enum CountingSheepContextualTip: String, Codable, CaseIterable, Hashable, Identifiable {
    case practice
    case nights
    case farm
    case settings
    case phoneBreak
    case trailNote
    case barnCapacity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .practice: return "Try a five-minute practice"
        case .nights: return "Your nights, kept together"
        case .farm: return "Ollie’s finds lead here"
        case .settings: return "Your plan lives here"
        case .phoneBreak: return "A break outside bedtime"
        case .trailNote: return "Search Journal keeps the record"
        case .barnCapacity: return "The discovery stays safe"
        }
    }

    var message: String {
        switch self {
        case .practice:
            return "A short, optional Wind Down practice creates a real Nights record. It does not count as a protected night."
        case .nights:
            return "Wind Down is your nightly ritual.\nPhone Away stays here as a smaller, separate record."
        case .farm:
            return "Wind Down is when Ollie may bring a missing sheep home.\nPhone Away minutes wait as gift progress."
        case .settings:
            return "Change Wind Down, connections, and guidance here.\nYou can replay this guide whenever you like."
        case .phoneBreak:
            return "Start one now or save one for later.\nEvery \(PhoneAwaySearchMeter.maximumMinutes) completed minutes, Ollie can look for a missing sheep after three Wind Downs."
        case .trailNote:
            return "A homecoming means Ollie found a missing sheep.\nA clue means Ollie will look again another night."
        case .barnCapacity:
            return "If The Barn is full, make room or open a new pasture.\nThe discovery stays in the Search Journal."
        }
    }
}

enum CountingSheepOrientationMilestone: String, Codable, CaseIterable, Hashable {
    case homeExplained
    case nightsExplored
    case farmExplored
    case settingsExplored
    case windDownSaved
    case practiceStarted
    case practiceCompleted
    case practiceRecordViewed
}

/// The resumable first-run guide is separate from the Wind Down state machine.
/// Schema 6 stores chapter-scoped progress while retaining the schema-five
/// fields so existing first-run JSON can migrate without changing rewards or
/// Farm ownership.
struct CountingSheepOrientationState: Codable, Equatable {
    static let currentSchemaVersion = 6

    var schemaVersion: Int
    var status: CountingSheepOrientationStatus
    var currentStep: CountingSheepOrientationStep
    var milestones: Set<CountingSheepOrientationMilestone>
    var practicePeriodID: UUID?
    var practiceRunID: UUID?
    var seenContextualTips: Set<CountingSheepContextualTip>
    var contextualTipsDisabled: Bool
    var skippedLessons: Set<CountingSheepOrientationStep>
    var farmTutorialActions: Set<FirstRunFarmAction>
    var continueCardDismissed: Bool
    var practiceRewardRoutedToFarm: Bool
    var slumberPartyUnavailableAcknowledged: Bool
    var activeChapter: FirstRunGuideChapter?
    var chapterStepIndex: Int
    var completedChapters: Set<FirstRunGuideChapter>
    var deferredChapters: Set<FirstRunGuideChapter>
    var presentationState: FirstRunGuidePresentationState
    var scrollAnchor: String?

    static let fresh = Self(
        schemaVersion: currentSchemaVersion,
        status: .notStarted,
        currentStep: .home,
        milestones: [],
        practicePeriodID: nil,
        practiceRunID: nil,
        seenContextualTips: [],
        contextualTipsDisabled: false,
        skippedLessons: [],
        farmTutorialActions: [],
        continueCardDismissed: false,
        practiceRewardRoutedToFarm: false,
        slumberPartyUnavailableAcknowledged: false,
        activeChapter: .homeBasics,
        chapterStepIndex: 0,
        completedChapters: [],
        deferredChapters: [],
        presentationState: .active,
        scrollAnchor: nil
    )

    init(
        schemaVersion: Int = currentSchemaVersion,
        status: CountingSheepOrientationStatus = .notStarted,
        currentStep: CountingSheepOrientationStep = .home,
        milestones: Set<CountingSheepOrientationMilestone> = [],
        practicePeriodID: UUID? = nil,
        practiceRunID: UUID? = nil,
        seenContextualTips: Set<CountingSheepContextualTip> = [],
        contextualTipsDisabled: Bool = false,
        skippedLessons: Set<CountingSheepOrientationStep> = [],
        farmTutorialActions: Set<FirstRunFarmAction> = [],
        continueCardDismissed: Bool = false,
        practiceRewardRoutedToFarm: Bool = false,
        slumberPartyUnavailableAcknowledged: Bool = false,
        activeChapter: FirstRunGuideChapter? = .homeBasics,
        chapterStepIndex: Int = 0,
        completedChapters: Set<FirstRunGuideChapter> = [],
        deferredChapters: Set<FirstRunGuideChapter> = [],
        presentationState: FirstRunGuidePresentationState = .active,
        scrollAnchor: String? = nil
    ) {
        self.schemaVersion = max(schemaVersion, Self.currentSchemaVersion)
        self.status = status
        self.currentStep = currentStep.normalized
        self.milestones = milestones
        self.practicePeriodID = practicePeriodID
        self.practiceRunID = practiceRunID
        self.seenContextualTips = seenContextualTips
        self.contextualTipsDisabled = contextualTipsDisabled
        self.skippedLessons = Set(skippedLessons.map(\.normalized))
        self.farmTutorialActions = farmTutorialActions
        self.continueCardDismissed = continueCardDismissed
        self.practiceRewardRoutedToFarm = practiceRewardRoutedToFarm
        self.slumberPartyUnavailableAcknowledged = slumberPartyUnavailableAcknowledged
        self.activeChapter = status == .completed || status == .skipped ? nil : activeChapter
        self.chapterStepIndex = max(0, chapterStepIndex)
        self.completedChapters = completedChapters
        self.deferredChapters = deferredChapters
        self.presentationState = status == .completed || status == .skipped
            ? .idle
            : status == .dismissed ? .paused : presentationState
        self.scrollAnchor = scrollAnchor
    }

    var isGuideActive: Bool {
        status != .skipped && status != .completed && activeChapter != nil
    }

    var isVisibleOnHome: Bool {
        isGuideActive && presentationState == .active && FirstRunJourney.surface(for: currentStep) == .home
    }

    var canResume: Bool { presentationState == .paused }

    var isComplete: Bool { status == .completed }

    func shouldShowContinueCard(isCoachMarkPresented: Bool) -> Bool {
        guard status != .skipped, status != .completed, activeChapter != nil else { return false }
        if continueCardDismissed { return false }
        guard presentationState == .paused else { return false }
        return !isCoachMarkPresented
    }

    mutating func mark(_ milestone: CountingSheepOrientationMilestone) {
        guard status != .skipped else { return }
        milestones.insert(milestone)
        if milestone == .practiceCompleted {
            milestones.insert(.practiceStarted)
        }
        if milestone == .practiceRecordViewed {
            milestones.insert(.practiceCompleted)
            milestones.insert(.practiceStarted)
        }
    }

    mutating func advanceTour(context: FirstRunAdvanceContext = .defaults) {
        guard isGuideActive else { return }
        markLessonSeen()
        guard let chapter = activeChapter else { return }
        let steps = FirstRunJourney.visibleSteps(for: chapter)
        if let currentIndex = steps.firstIndex(of: currentStep.normalized), currentIndex + 1 < steps.count {
            chapterStepIndex = currentIndex + 1
            currentStep = steps[chapterStepIndex]
            status = .inProgress
            presentationState = .active
            continueCardDismissed = false
        } else {
            completeChapter(chapter)
        }
    }

    mutating func moveBack(context: FirstRunAdvanceContext = .defaults) {
        guard isGuideActive else { return }
        guard let chapter = activeChapter else { return }
        let steps = FirstRunJourney.visibleSteps(for: chapter)
        if let currentIndex = steps.firstIndex(of: currentStep.normalized), currentIndex > 0 {
            chapterStepIndex = currentIndex - 1
            currentStep = steps[chapterStepIndex]
        }
        status = .inProgress
        presentationState = .active
        continueCardDismissed = false
        _ = context
    }

    mutating func skipCurrentLesson(context: FirstRunAdvanceContext = .defaults) {
        guard isGuideActive else { return }
        skippedLessons.insert(currentStep.normalized)
        advanceTour(context: context)
    }

    mutating func completeTour() {
        guard status != .skipped else { return }
        status = .completed
        currentStep = .completion
        continueCardDismissed = true
        activeChapter = nil
        presentationState = .idle
    }

    mutating func completeChapter(_ chapter: FirstRunGuideChapter) {
        completedChapters.insert(chapter)
        activeChapter = nil
        chapterStepIndex = 0
        presentationState = .idle
        continueCardDismissed = true
        status = .inProgress
        currentStep = chapter == .homeBasics ? .completion : .farmSearch
    }

    mutating func offerChapter(_ chapter: FirstRunGuideChapter) {
        guard status != .skipped, status != .completed,
              !completedChapters.contains(chapter) else { return }
        activeChapter = chapter
        chapterStepIndex = 0
        currentStep = FirstRunJourney.steps(for: chapter)[0]
        presentationState = .offered
        continueCardDismissed = false
        status = .inProgress
    }

    mutating func startOfferedChapter() {
        guard activeChapter != nil, presentationState == .offered else { return }
        presentationState = .active
        status = .inProgress
        continueCardDismissed = false
    }

    mutating func deferActiveChapter() {
        guard let activeChapter else { return }
        deferredChapters.insert(activeChapter)
        self.activeChapter = activeChapter
        presentationState = .paused
        continueCardDismissed = true
        status = .dismissed
    }

    mutating func recordPracticePeriod(_ periodID: UUID) {
        practicePeriodID = periodID
    }

    mutating func recordPracticeRun(_ runID: UUID) {
        practiceRunID = runID
        mark(.practiceStarted)
    }

    mutating func recordPracticeCompleted(context: FirstRunAdvanceContext = .defaults) {
        mark(.practiceCompleted)
        if isGuideActive, currentStep.normalized == .practiceOffer {
            currentStep = .practiceReward
            status = .inProgress
        }
        _ = context
    }

    mutating func markPracticeRewardRoutedToFarm() {
        guard !practiceRewardRoutedToFarm else { return }
        practiceRewardRoutedToFarm = true
    }

    mutating func recordFarmAction(_ action: FirstRunFarmAction) {
        farmTutorialActions.insert(action)
        if action == .sheared {
            farmTutorialActions.insert(.skippedShear)
        }
        if action == .equippedWearable {
            farmTutorialActions.insert(.claimedWearable)
        }
    }

    func hasRecorded(_ action: FirstRunFarmAction) -> Bool {
        farmTutorialActions.contains(action)
    }

    mutating func acknowledgeSlumberPartyUnavailable() {
        slumberPartyUnavailableAcknowledged = true
    }

    mutating func dismiss() {
        guard status != .skipped, status != .completed else { return }
        status = .dismissed
        presentationState = .paused
    }

    mutating func dismissContinueCard() {
        continueCardDismissed = true
        if activeChapter != nil {
            status = .dismissed
            presentationState = .paused
        }
    }

    mutating func resume() {
        guard activeChapter != nil,
              status == .dismissed || presentationState == .paused else { return }
        status = .inProgress
        continueCardDismissed = false
        presentationState = .active
    }

    mutating func skipPermanently() {
        guard status != .completed else { return }
        status = .skipped
        continueCardDismissed = true
        activeChapter = nil
        presentationState = .idle
    }

    var canShowContextualTips: Bool {
        status != .skipped && status != .dismissed && !contextualTipsDisabled
    }

    func nextContextualTip(
        from candidates: [CountingSheepContextualTip],
        isWindDownActive: Bool = false
    ) -> CountingSheepContextualTip? {
        guard canShowContextualTips, !isWindDownActive else { return nil }
        return candidates.first { !seenContextualTips.contains($0) }
    }

    mutating func markContextualTipSeen(_ tip: CountingSheepContextualTip) {
        guard canShowContextualTips else { return }
        seenContextualTips.insert(tip)
        if tip == .barnCapacity {
            seenContextualTips.insert(.farm)
        }
    }

    mutating func disableContextualTips() {
        contextualTipsDisabled = true
    }

    mutating func replay() {
        self = .fresh
        status = .inProgress
        presentationState = .active
    }

    private mutating func markLessonSeen() {
        switch currentStep.normalized {
        case .home: mark(.homeExplained)
        case .farmMeetSheep, .farmCapacity: mark(.farmExplored)
        case .settings: mark(.settingsExplored)
        case .nights: mark(.nightsExplored)
        default: break
        }
        if currentStep.normalized == .settings {
            seenContextualTips.insert(.settings)
        }
        if currentStep.normalized == .nights {
            seenContextualTips.insert(.nights)
        }
        if currentStep.normalized == .farmMeetSheep {
            seenContextualTips.insert(.farm)
        }
        if currentStep.normalized == .phoneAway {
            seenContextualTips.insert(.phoneBreak)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, status, currentStep, milestones
        case practicePeriodID, practiceRunID
        case seenContextualTips, contextualTipsDisabled
        case skippedLessons, farmTutorialActions
        case continueCardDismissed, practiceRewardRoutedToFarm
        case slumberPartyUnavailableAcknowledged
        case activeChapter, chapterStepIndex, completedChapters, deferredChapters
        case presentationState, scrollAnchor
        case homeExplained, nightsExplored, farmExplored, settingsExplored
        case windDownSaved, practiceStarted, practiceCompleted, practiceRecordViewed
        case dismissed, skipped, completed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let storedVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
        var decodedStatus = try container.decodeIfPresent(
            CountingSheepOrientationStatus.self,
            forKey: .status
        ) ?? .notStarted

        if try container.decodeIfPresent(Bool.self, forKey: .skipped) == true {
            decodedStatus = .skipped
        } else if try container.decodeIfPresent(Bool.self, forKey: .completed) == true {
            decodedStatus = .completed
        } else if try container.decodeIfPresent(Bool.self, forKey: .dismissed) == true {
            decodedStatus = .dismissed
        }

        var decodedMilestones = try container.decodeIfPresent(
            Set<CountingSheepOrientationMilestone>.self,
            forKey: .milestones
        ) ?? []
        let legacyFlags: [(CodingKeys, CountingSheepOrientationMilestone)] = [
            (.homeExplained, .homeExplained),
            (.nightsExplored, .nightsExplored),
            (.farmExplored, .farmExplored),
            (.settingsExplored, .settingsExplored),
            (.windDownSaved, .windDownSaved),
            (.practiceStarted, .practiceStarted),
            (.practiceCompleted, .practiceCompleted),
            (.practiceRecordViewed, .practiceRecordViewed)
        ]
        for (key, milestone) in legacyFlags where try container.decodeIfPresent(Bool.self, forKey: key) == true {
            decodedMilestones.insert(milestone)
        }

        if decodedStatus == .notStarted, !decodedMilestones.isEmpty {
            decodedStatus = .inProgress
        }

        var decodedStep: CountingSheepOrientationStep
        if storedVersion < 2 {
            decodedStep = decodedMilestones.contains(.homeExplained) ? .phoneAway : .home
        } else {
            decodedStep = try container.decodeIfPresent(
                CountingSheepOrientationStep.self,
                forKey: .currentStep
            ) ?? .home
        }
        if storedVersion < 5, decodedStep == .navigation {
            decodedStep = .phoneAway
        }

        schemaVersion = max(storedVersion, Self.currentSchemaVersion)
        status = decodedStatus
        currentStep = decodedStep.normalized
        milestones = decodedMilestones
        practicePeriodID = try container.decodeIfPresent(UUID.self, forKey: .practicePeriodID)
        practiceRunID = try container.decodeIfPresent(UUID.self, forKey: .practiceRunID)
        seenContextualTips = try container.decodeIfPresent(Set<CountingSheepContextualTip>.self, forKey: .seenContextualTips) ?? []
        contextualTipsDisabled = try container.decodeIfPresent(Bool.self, forKey: .contextualTipsDisabled) ?? false
        skippedLessons = Set(
            (try container.decodeIfPresent(Set<CountingSheepOrientationStep>.self, forKey: .skippedLessons) ?? [])
                .map(\.normalized)
        )
        farmTutorialActions = try container.decodeIfPresent(Set<FirstRunFarmAction>.self, forKey: .farmTutorialActions) ?? []
        continueCardDismissed = try container.decodeIfPresent(Bool.self, forKey: .continueCardDismissed) ?? false
        practiceRewardRoutedToFarm = try container.decodeIfPresent(Bool.self, forKey: .practiceRewardRoutedToFarm) ?? false
        slumberPartyUnavailableAcknowledged = try container.decodeIfPresent(Bool.self, forKey: .slumberPartyUnavailableAcknowledged) ?? false

        if storedVersion >= Self.currentSchemaVersion {
            activeChapter = try container.decodeIfPresent(FirstRunGuideChapter.self, forKey: .activeChapter)
            chapterStepIndex = try container.decodeIfPresent(Int.self, forKey: .chapterStepIndex) ?? 0
            completedChapters = try container.decodeIfPresent(Set<FirstRunGuideChapter>.self, forKey: .completedChapters) ?? []
            deferredChapters = try container.decodeIfPresent(Set<FirstRunGuideChapter>.self, forKey: .deferredChapters) ?? []
            presentationState = try container.decodeIfPresent(FirstRunGuidePresentationState.self, forKey: .presentationState) ?? .idle
            scrollAnchor = try container.decodeIfPresent(String.self, forKey: .scrollAnchor)
        } else {
            let migration = Self.migrateLegacyJourney(
                step: decodedStep.normalized,
                status: decodedStatus,
                skippedLessons: skippedLessons
            )
            activeChapter = migration.chapter
            chapterStepIndex = migration.index
            completedChapters = migration.completedChapters
            deferredChapters = migration.deferredChapters
            presentationState = migration.presentationState
            scrollAnchor = nil
            currentStep = migration.step
            if migration.contextualTip != nil {
                activeChapter = nil
                presentationState = .paused
                if decodedStatus == .dismissed {
                    status = .inProgress
                }
            }
        }
    }

    private struct LegacyJourneyMigration {
        var step: CountingSheepOrientationStep
        var chapter: FirstRunGuideChapter?
        var index: Int
        var completedChapters: Set<FirstRunGuideChapter>
        var deferredChapters: Set<FirstRunGuideChapter>
        var presentationState: FirstRunGuidePresentationState
        var contextualTip: CountingSheepContextualTip?
    }

    private static func migrateLegacyJourney(
        step: CountingSheepOrientationStep,
        status: CountingSheepOrientationStatus,
        skippedLessons: Set<CountingSheepOrientationStep>
    ) -> LegacyJourneyMigration {
        if status == .completed || step == .completion {
            return LegacyJourneyMigration(
                step: .completion,
                chapter: nil,
                index: 0,
                completedChapters: Set(FirstRunGuideChapter.allCases),
                deferredChapters: [],
                presentationState: .idle,
                contextualTip: nil
            )
        }

        let normalized = step.normalized
        if normalized == .practiceOffer || normalized == .practiceReward {
            return LegacyJourneyMigration(
                step: normalized,
                chapter: nil,
                index: 0,
                completedChapters: [],
                deferredChapters: [],
                presentationState: .paused,
                contextualTip: .practice
            )
        }
        if normalized == .settings || normalized == .nights || normalized == .slumberParty {
            let tip: CountingSheepContextualTip? = normalized == .settings
                ? .settings
                : normalized == .nights ? .nights : nil
            return LegacyJourneyMigration(
                step: normalized,
                chapter: nil,
                index: 0,
                completedChapters: [],
                deferredChapters: normalized == .slumberParty ? [.farmTour] : [],
                presentationState: .paused,
                contextualTip: tip
            )
        }

        let chapter = FirstRunJourney.chapter(for: normalized) ?? .homeBasics
        let steps = FirstRunJourney.steps(for: chapter)
        let migrationStep: CountingSheepOrientationStep = normalized == .farmWool || normalized == .farmShear || normalized == .farmCurrency || normalized == .farmClaimWearable || normalized == .farmEquipWearable
            ? .farmCapacity
            : normalized == .navigation ? .rootTabs : normalized
        let index = steps.firstIndex(of: migrationStep) ?? 0
        return LegacyJourneyMigration(
            step: migrationStep,
            chapter: chapter,
            index: index,
            completedChapters: [],
            deferredChapters: [],
            presentationState: status == .dismissed ? .paused : .active,
            contextualTip: nil
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(status, forKey: .status)
        try container.encode(currentStep.normalized, forKey: .currentStep)
        try container.encode(milestones, forKey: .milestones)
        try container.encodeIfPresent(practicePeriodID, forKey: .practicePeriodID)
        try container.encodeIfPresent(practiceRunID, forKey: .practiceRunID)
        try container.encode(seenContextualTips, forKey: .seenContextualTips)
        try container.encode(contextualTipsDisabled, forKey: .contextualTipsDisabled)
        try container.encode(skippedLessons, forKey: .skippedLessons)
        try container.encode(farmTutorialActions, forKey: .farmTutorialActions)
        try container.encode(continueCardDismissed, forKey: .continueCardDismissed)
        try container.encode(practiceRewardRoutedToFarm, forKey: .practiceRewardRoutedToFarm)
        try container.encode(slumberPartyUnavailableAcknowledged, forKey: .slumberPartyUnavailableAcknowledged)
        try container.encodeIfPresent(activeChapter, forKey: .activeChapter)
        try container.encode(chapterStepIndex, forKey: .chapterStepIndex)
        try container.encode(completedChapters, forKey: .completedChapters)
        try container.encode(deferredChapters, forKey: .deferredChapters)
        try container.encode(presentationState, forKey: .presentationState)
        try container.encodeIfPresent(scrollAnchor, forKey: .scrollAnchor)
    }
}
