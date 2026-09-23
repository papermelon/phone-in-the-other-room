import Foundation

/// Surfaces the in-app guide uses after initial setup. Coach marks point at the
/// real production interface on these tabs rather than a separate lesson modal.
enum FirstRunSurface: String, Codable, Equatable {
    case home
    case farm
    case settings
    case nights
}

enum FirstRunGuideChapter: String, Codable, CaseIterable, Hashable {
    case homeBasics
    case farmTour

    var title: String {
        switch self {
        case .homeBasics: return "HOME BASICS"
        case .farmTour: return "AROUND THE FARM"
        }
    }
}

enum FirstRunGuidePresentationState: String, Codable, Equatable {
    case idle
    case offered
    case active
    case paused
}

enum FirstRunGuidePresentation: String, Codable, Equatable {
    case coachMark
    case practiceSheet
    case embeddedCard
    case contextualTip
}

enum FirstRunFarmAction: String, Codable, CaseIterable, Hashable {
    case metSheep
    case sawCapacity
    case sawWool
    case sheared
    case skippedShear
    case claimedWearable
    case equippedWearable
    case visitedShop
    case visitedSearch
    case choseTrackedSheep

    var isIdempotent: Bool { true }
}

struct FirstRunAdvanceContext: Equatable {
    var practiceCompleted: Bool
    var slumberPartyAvailable: Bool
    var showClaimWearable: Bool
    var showEquipWearable: Bool

    static let defaults = Self(
        practiceCompleted: false,
        slumberPartyAvailable: false,
        showClaimWearable: true,
        showEquipWearable: true
    )

    /// Kept for decoding callers from the expanded schema-five journey.
    var wearableLessonsPending: Bool { showClaimWearable || showEquipWearable }
}

enum FirstRunJourney {
    static let homeBasicsSteps: [CountingSheepOrientationStep] = [
        .home, .start, .phoneAway, .rootTabs
    ]

    static let farmTourSteps: [CountingSheepOrientationStep] = [
        .farmMeetSheep, .farmCapacity, .farmShop, .farmSearch
    ]

    static func steps(for chapter: FirstRunGuideChapter) -> [CountingSheepOrientationStep] {
        switch chapter {
        case .homeBasics: return homeBasicsSteps
        case .farmTour: return farmTourSteps
        }
    }

    static func chapter(for step: CountingSheepOrientationStep) -> FirstRunGuideChapter? {
        switch step.normalized {
        case .home, .start, .phoneAway, .rootTabs, .navigation: return .homeBasics
        case .farmMeetSheep, .farmCapacity, .farmShop, .farmSearch: return .farmTour
        default: return nil
        }
    }

    static let orderedSteps: [CountingSheepOrientationStep] = [
        .home,
        .start,
        .phoneAway,
        .practiceOffer,
        .practiceReward,
        .farmMeetSheep,
        .farmCapacity,
        .farmWool,
        .farmShear,
        .farmCurrency,
        .farmClaimWearable,
        .farmEquipWearable,
        .farmShop,
        .farmSearch,
        .slumberParty,
        .settings,
        .nights,
        .completion
    ]

    static func visibleSteps(context: FirstRunAdvanceContext) -> [CountingSheepOrientationStep] {
        orderedSteps.filter { step in
            switch step {
            case .practiceReward:
                return context.practiceCompleted
            case .farmClaimWearable:
                return context.showClaimWearable
            case .farmEquipWearable:
                return context.showEquipWearable
            default:
                return true
            }
        }
    }

    static func visibleSteps(for chapter: FirstRunGuideChapter) -> [CountingSheepOrientationStep] {
        steps(for: chapter).map(\.normalized)
    }

    static func surface(for step: CountingSheepOrientationStep) -> FirstRunSurface {
        switch step.normalized {
        case .home, .start, .phoneAway, .rootTabs, .practiceOffer, .practiceReward, .slumberParty, .completion, .navigation:
            return .home
        case .farmMeetSheep, .farmCapacity, .farmWool, .farmShear, .farmCurrency,
             .farmClaimWearable, .farmEquipWearable, .farmShop, .farmSearch:
            return .farm
        case .settings:
            return .settings
        case .nights:
            return .nights
        }
    }

    static func usesCoachMark(_ step: CountingSheepOrientationStep) -> Bool {
        switch step.normalized {
        case .practiceOffer, .practiceReward, .slumberParty, .completion:
            return false
        default:
            return true
        }
    }

    static func number(
        for step: CountingSheepOrientationStep,
        chapter: FirstRunGuideChapter
    ) -> Int {
        (visibleSteps(for: chapter).firstIndex(of: step.normalized) ?? 0) + 1
    }

    static func count(for chapter: FirstRunGuideChapter) -> Int {
        visibleSteps(for: chapter).count
    }

    static func next(
        after step: CountingSheepOrientationStep,
        context: FirstRunAdvanceContext
    ) -> CountingSheepOrientationStep? {
        let steps = visibleSteps(context: context)
        let normalized = step.normalized
        if let index = steps.firstIndex(of: normalized) {
            let nextIndex = index + 1
            return nextIndex < steps.count ? steps[nextIndex] : nil
        }
        guard let orderedIndex = orderedSteps.firstIndex(of: normalized) else {
            return steps.first
        }
        return steps.first { candidate in
            guard let candidateIndex = orderedSteps.firstIndex(of: candidate) else { return false }
            return candidateIndex > orderedIndex
        }
    }

    static func previous(
        before step: CountingSheepOrientationStep,
        context: FirstRunAdvanceContext
    ) -> CountingSheepOrientationStep? {
        let steps = visibleSteps(context: context)
        let normalized = step.normalized
        if let index = steps.firstIndex(of: normalized), index > 0 {
            return steps[index - 1]
        }
        guard let orderedIndex = orderedSteps.firstIndex(of: normalized) else {
            return nil
        }
        return steps.last { candidate in
            guard let candidateIndex = orderedSteps.firstIndex(of: candidate) else { return false }
            return candidateIndex < orderedIndex
        }
    }

    static func number(for step: CountingSheepOrientationStep, context: FirstRunAdvanceContext) -> Int {
        let steps = visibleSteps(context: context)
        return (steps.firstIndex(of: step.normalized) ?? 0) + 1
    }

    static func count(context: FirstRunAdvanceContext) -> Int {
        visibleSteps(context: context).count
    }

    static func resumeDestination(
        for state: CountingSheepOrientationState
    ) -> FirstRunResumeDestination? {
        let isContextualDestination = state.activeChapter == nil
            && [.practiceOffer, .practiceReward, .slumberParty, .settings, .nights].contains(state.currentStep.normalized)
        guard state.presentationState == .paused || state.presentationState == .active || isContextualDestination else { return nil }
        let step = state.currentStep.normalized
        let presentation: FirstRunGuidePresentation
        switch step {
        case .practiceOffer: presentation = .practiceSheet
        case .practiceReward, .slumberParty, .completion: presentation = .embeddedCard
        case .settings, .nights: presentation = .contextualTip
        default: presentation = .coachMark
        }
        return FirstRunResumeDestination(
            surface: surface(for: step),
            resetNavigation: true,
            presentation: presentation,
            step: step,
            chapter: state.activeChapter,
            scrollAnchor: state.scrollAnchor
        )
    }
}

struct FirstRunResumeDestination: Equatable {
    var surface: FirstRunSurface
    var resetNavigation: Bool
    var presentation: FirstRunGuidePresentation
    var step: CountingSheepOrientationStep
    var chapter: FirstRunGuideChapter?
    var scrollAnchor: String?

    var presentPracticeOffer: Bool { presentation == .practiceSheet }
}

enum FirstRunGuideCopy {
    static func title(for step: CountingSheepOrientationStep) -> String {
        switch step.normalized {
        case .home: return "Tonight’s Wind Down"
        case .start: return "Begin your Wind Down"
        case .phoneAway: return "Phone Away"
        case .rootTabs: return "Find your way around"
        case .practiceOffer: return "A five-minute practice"
        case .practiceReward: return "A welcome gift came home"
        case .farmMeetSheep: return "Meet the flock"
        case .farmCapacity: return "Make room for your flock"
        case .farmWool: return "Sheep grow wool"
        case .farmShear: return "Shearing is a choice"
        case .farmCurrency: return "Wool is Farm currency"
        case .farmClaimWearable: return "A welcome gift for the shepherd"
        case .farmEquipWearable: return "Put the gift on"
        case .farmShop: return "The Farm Shop"
        case .farmSearch: return "Ollie’s Search"
        case .slumberParty: return "A shared ritual with people you know"
        case .settings: return "Your plan lives in Settings"
        case .nights: return "Nights keeps the record"
        case .completion: return "You’re ready"
        case .navigation: return "Phone Away"
        }
    }

    static func message(for step: CountingSheepOrientationStep) -> String {
        switch step.normalized {
        case .home:
            return "Bedtime, wake time, and both quiet windows live here."
        case .start:
            return "At Wind Down time, this button says Start Wind Down. Earlier in the day, it offers Phone Away for time beyond your screen. Each starts its own kind of session."
        case .phoneAway:
            return "Use Phone Away for a break from your phone at any time of day. Read, cook, work, or spend time with someone. These minutes appear separately in Nights."
        case .rootTabs:
            return "Home, Nights, Farm, and Settings stay close at the bottom of every screen."
        case .practiceOffer:
            return "This creates a real Nights record without counting toward Wind Down search progress or the Phone Away meter. Finishing this one-time introduction lets Ollie bring home the second starter sheep."
        case .practiceReward:
            return "Practice brought a welcome gift home. The Farm is waiting."
        case .farmMeetSheep:
            return "A new Farm begins with one welcome-gift sheep. Practice can bring a second one home."
        case .farmCapacity:
            return "Your Barn has room for a set number of sheep. When it fills, you can make room or open another pasture. Search Journal keeps every discovery."
        case .farmWool:
            return "Wind Down and Phone Away credit help your sheep grow wool. Shorter sessions count too; Brief Access time is left out."
        case .farmShear:
            return "Shearing gathers wool and keeps the sheep. Fleece grows back. You can skip this for now."
        case .farmCurrency:
            return "Wool is the Farm currency. Shear or trade for it, then spend it in the Shop."
        case .farmClaimWearable:
            return "A free outfit for your shepherd is waiting here. Claim it without spending wool."
        case .farmEquipWearable:
            return "The gift is yours. Put it on the shepherd when you are ready."
        case .farmShop:
            return "Spend wool on more room for sheep, Farm decorations, and clothes. Your welcome gifts are free."
        case .farmSearch:
            return "Wind Down, Screen-Free Morning and Phone Away each give Ollie ways to search. Open this board to choose a sheep to favour, or tap its question mark for the full guide. Search Journal keeps every find and clue."
        case .slumberParty:
            return "Invite people you know to a long-lived private group. Seven-night rounds organize shared progress, cheers, and Farm rewards."
        case .settings:
            return "Edit Wind Down here. Screen Time protection is required for new starts. Apple Health is optional context beside Nights. Slumber Party and this guide have their own controls."
        case .nights:
            return "Wind Down before-bed minutes, Screen-Free Morning elapsed minutes, Phone Away, and practice stay distinct. Apple Health is optional context; Screen Time protection is required for new starts. Nights is a factual record, not a sleep score."
        case .completion:
            return "Wind Down, the Farm, and Nights are ready whenever you are. You can replay this guide in Settings."
        case .navigation:
            return "Take a break from your phone whenever you need one. Phone Away minutes appear separately from Wind Down."
        }
    }

    static let continueCardTitle = "Resume Home basics"
    static let continueCardDetail = "The next Home tip is waiting on the real screen."
    static func continueCardTitle(for chapter: FirstRunGuideChapter?) -> String {
        switch chapter {
        case .homeBasics: return "Resume Home basics"
        case .farmTour: return "Resume the Farm tour"
        case nil: return "Resume your guide"
        }
    }
    static func continueCardDetail(for chapter: FirstRunGuideChapter?, step: CountingSheepOrientationStep) -> String {
        switch chapter {
        case .homeBasics: return "Continue with \(title(for: step))."
        case .farmTour: return "Continue with \(title(for: step)) on the Farm."
        case nil: return "A guide tip is ready when you are."
        }
    }
    static let continueCardResume = "Resume"
    static let continueCardDismiss = "Dismiss for now"
    static let skipForNow = "Skip for now"
    static let doThisLater = "Do this later"

    static let slumberPartyCreate = "Create a Slumber Party"
    static let slumberPartyJoin = "Join with a code"
    static let slumberPartyLater = "Do this later"
    static let slumberPartyUnavailable =
        "Slumber Party is not available in this copy of Counting Sheep. Wind Down, the Farm, and Nights are ready."

    static let screenTimePermission =
        "Screen Time protection is required for new starts. Counting Sheep requests limits for the apps and categories you choose from Wind Down start through Screen-Free Morning, including overnight, and during Phone Away. Your selection stays in Apple’s system, and Counting Sheep remains available."
    static let healthPermission =
        "Apple Health can place optional sleep duration and stages beside your Wind Down record in Nights. It does not decide whether Wind Down was completed or whether Ollie finds a sheep."
    static let permissionCanDecline = "Apple Health is optional. Screen Time protection must be ready before a new Wind Down, Screen-Free Morning, or Phone Away can start."

    static let practiceOfferTitle = "A five-minute practice"
    static let practiceStart = "Try 5 minutes"
    static let practiceGiftEyebrow = "A WELCOME GIFT"
    static let practiceGiftTitle = "Ollie brought a second sheep home."
    static let practiceGiftTitleAlreadyGranted = "Practice is in Nights. Your welcome-gift sheep is still on the Farm."

    static func practiceGiftTitle(grantedNewSheep: Bool) -> String {
        grantedNewSheep ? practiceGiftTitle : practiceGiftTitleAlreadyGranted
    }
    static let practiceGiftSeeFarm = "See them on the Farm"

    static let aboutIdeasAndSources = "About these ideas and sources"
}
