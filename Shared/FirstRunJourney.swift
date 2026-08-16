import Foundation

/// Surfaces the in-app guide uses after initial setup. Coach marks point at the
/// real production interface on these tabs rather than a separate lesson modal.
enum FirstRunSurface: String, Codable, Equatable {
    case home
    case farm
    case settings
    case nights
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

    /// Remaining Farm-gift lessons, used when skipping claim also skips equip.
    var wearableLessonsPending: Bool { showClaimWearable || showEquipWearable }
}

enum FirstRunJourney {
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

    static func surface(for step: CountingSheepOrientationStep) -> FirstRunSurface {
        switch step.normalized {
        case .home, .start, .phoneAway, .practiceOffer, .practiceReward, .slumberParty, .completion, .navigation:
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
        guard state.status == .inProgress || state.status == .dismissed else { return nil }
        let step = state.currentStep.normalized
        return FirstRunResumeDestination(
            surface: surface(for: step),
            presentPracticeOffer: step == .practiceOffer
        )
    }
}

struct FirstRunResumeDestination: Equatable {
    var surface: FirstRunSurface
    var presentPracticeOffer: Bool
}

enum FirstRunGuideCopy {
    static func title(for step: CountingSheepOrientationStep) -> String {
        switch step.normalized {
        case .home: return "Tonight’s Wind Down"
        case .start: return "Start what’s ready"
        case .phoneAway: return "Phone Away"
        case .practiceOffer: return "A five-minute practice"
        case .practiceReward: return "A welcome gift came home"
        case .farmMeetSheep: return "Meet the flock"
        case .farmCapacity: return "The Barn has a size"
        case .farmWool: return "Sheep grow wool"
        case .farmShear: return "Shearing is a choice"
        case .farmCurrency: return "Wool is Farm currency"
        case .farmClaimWearable: return "A welcome gift for the shepherd"
        case .farmEquipWearable: return "Put the gift on"
        case .farmShop: return "The Farm Shop"
        case .farmSearch: return "Ollie’s Search"
        case .slumberParty: return "Choose a Wind Down goal together"
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
            return "When Wind Down is eligible, this starts it. Putting the phone away is always first."
        case .phoneAway:
            return "A shorter phone-free stretch outside your usual Wind Down. It stays a separate record."
        case .practiceOffer:
            return "This creates a real Nights record. It is not a protected night, and it does not add to the usual Phone Away search meter. Finishing this one-time introduction lets Ollie bring home the second starter sheep."
        case .practiceReward:
            return "Practice brought a welcome gift home. The Farm is waiting."
        case .farmMeetSheep:
            return "A new Farm begins with one welcome-gift sheep. Practice can bring a second one home."
        case .farmCapacity:
            return "The Barn holds a finite flock. If it fills, make room or open a new pasture. Discoveries stay in Search Journal."
        case .farmWool:
            return "Sheep grow wool over completed Wind Downs. The current wool sits on this Farm bar."
        case .farmShear:
            return "Shearing gathers wool and keeps the sheep. Fleece grows back. You can skip this for now."
        case .farmCurrency:
            return "Wool is the Farm currency. Shear or trade for it, then spend it in the Shop."
        case .farmClaimWearable:
            return "Your Wind Down starting point left a free shepherd wearable waiting here. Claiming it does not spend wool."
        case .farmEquipWearable:
            return "The gift is yours. Put it on the shepherd when you are ready."
        case .farmShop:
            return "The Shop sells capacity, decoration, and clothes for wool. Welcome gifts stay free and already claimed."
        case .farmSearch:
            return "Ollie’s Search is the missing-sheep board. Search Journal keeps the history. Choose one missing sheep for Ollie to favour."
        case .slumberParty:
            return "Invite people you know, share what helps, and keep one another going for seven nights."
        case .settings:
            return "Edit Wind Down here. Screen Time covers the apps you choose. Apple Health can sit beside Nights as optional context. Sharing controls and this guide live here too."
        case .nights:
            return "Practice, Phone Away, and Wind Down stay distinct. Health and Screen Time are optional context. Nights is a factual record, not a sleep score."
        case .completion:
            return "Wind Down, the Farm, and Nights are ready whenever you are. You can replay this guide in Settings."
        case .navigation:
            return "A shorter phone-free stretch outside your usual Wind Down. It stays a separate record."
        }
    }

    static let continueCardTitle = "Continue getting to know Counting Sheep"
    static let continueCardDetail = "A short guide is waiting on the real Home, Farm, Settings, and Nights screens."
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
        "App limits let Counting Sheep cover the apps you choose while Wind Down is active. Your selected apps stay in Apple’s Screen Time system, and Counting Sheep remains available."
    static let healthPermission =
        "Apple Health can place optional sleep duration and stages beside your Wind Down record in Nights. It does not decide whether Wind Down was completed or whether Ollie finds a sheep."
    static let permissionCanDecline = "You can decline and come back to this later in Settings."

    static let practiceOfferTitle = "A five-minute practice"
    static let practiceStart = "Try 5 minutes"
    static let practiceGiftEyebrow = "A WELCOME GIFT"
    static let practiceGiftTitle = "Ollie brought a second sheep home."
    static let practiceGiftTitleAlreadyGranted = "Practice is in Nights. Your welcome-gift sheep is still on the Farm."

    static func practiceGiftTitle(grantedNewSheep: Bool) -> String {
        grantedNewSheep ? practiceGiftTitle : practiceGiftTitleAlreadyGranted
    }
    static let practiceGiftSeeFarm = "See them on the Farm"

    static let recommendationEyebrow = "YOUR WIND DOWN STARTING POINT"
    static let recommendationTitle = "Your Wind Down starting point"
    static let recommendationDetail = "Based on what you told us, these ideas may be useful places to begin."
    static let aboutIdeasAndSources = "About these ideas and sources"
    static let recommendedRoutine = "Recommended routine"
    static let freeWearable = "A free welcome gift for the shepherd"
}
