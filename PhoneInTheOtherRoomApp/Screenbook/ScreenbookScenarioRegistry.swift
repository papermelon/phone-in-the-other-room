#if DEBUG
import Foundation

enum ScreenbookScenarioRegistry {
    static let captureProfile = "iphone17-ios26.5-enSG-standard"

    static let scenarios: [ScreenbookScenario] = ScreenbookScenarioKind.allCases.map(descriptor)

    static var manifest: ScreenbookRegistryManifest {
        ScreenbookRegistryManifest(
            schemaVersion: 1,
            captureProfile: captureProfile,
            scenarios: scenarios
        )
    }

    static func scenario(id: String) -> ScreenbookScenario? {
        scenarios.first { $0.id == id }
    }

    static func encodedManifest() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(manifest)
    }

    private static func descriptor(_ kind: ScreenbookScenarioKind) -> ScreenbookScenario {
        switch kind {
        case .onboardingWelcome:
            return ScreenbookScenario(
                id: kind.rawValue,
                title: "Welcome",
                description: "The production welcome step inside the first-run onboarding context.",
                surface: "iphone",
                journey: "onboarding",
                route: "onboarding",
                state: "welcome",
                tags: ["first-run", "welcome", "quiet-time"],
                fixtureVersion: 1,
                captureProfile: captureProfile,
                captureProvenance: "automated-simulator",
                dependencies: commonDependencies + [
                    "PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingFlowView.swift",
                    "PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingWelcomeStepView.swift",
                    "PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingComponents.swift"
                ],
                copy: [
                    .stable(AppCopy.OnboardingWelcome.eyebrow, file: "PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingWelcomeStepView.swift", symbol: "OnboardingWelcomeStep"),
                    .stable(AppCopy.OnboardingWelcome.title, file: "PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingWelcomeStepView.swift", symbol: "OnboardingWelcomeStep"),
                    .stable(AppCopy.OnboardingWelcome.detail, file: "PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingWelcomeStepView.swift", symbol: "OnboardingWelcomeStep"),
                    .provisional(id: "iphone.onboarding.welcome.primary-button.provisional", rendered: "Set up my Wind Down", file: "PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingFlowView.swift", symbol: "OnboardingFlowView.primaryButtonTitle"),
                    .provisional(id: "iphone.onboarding.welcome.ollie-detail.provisional", rendered: "Ollie keeps watch while the phone rests somewhere else.", file: "PhoneInTheOtherRoomApp/Views/Onboarding/OnboardingWelcomeStepView.swift", symbol: "OnboardingWelcomeStep")
                ],
                warnings: coverageWarning
            )
        case .configuredHome:
            return ScreenbookScenario(
                id: kind.rawValue,
                title: "Configured Home",
                description: "Home with a saved Wind Down, settled progress, and an upcoming start.",
                surface: "iphone",
                journey: "night-watch",
                route: "home",
                state: "configured",
                tags: ["home", "configured", "upcoming"],
                fixtureVersion: 1,
                captureProfile: captureProfile,
                captureProvenance: "automated-simulator",
                dependencies: commonDependencies + [
                    "PhoneInTheOtherRoomApp/Views/HomeView.swift",
                    "PhoneInTheOtherRoomApp/Views/PixelHomeDashboard.swift",
                    "Shared/NightWatch.swift",
                    "Shared/Models/OllieModels.swift"
                ],
                copy: [
                    .stable(AppCopy.ConfiguredHome.quietStatement, file: "PhoneInTheOtherRoomApp/Views/PixelHomeDashboard.swift", symbol: "PixelHomeDashboardContent"),
                    .stable(AppCopy.ConfiguredHome.startButton, file: "PhoneInTheOtherRoomApp/Views/PixelHomeDashboard.swift", symbol: "PixelHomeDashboardContent.primaryTitle"),
                    .provisional(id: "iphone.home.configured.purpose.provisional", rendered: "Make room for a book", file: "Shared/OfflinePurpose.swift", symbol: "OfflinePurposeProfile.inAppDisplayPhrase"),
                    .provisional(id: "iphone.home.configured.schedule.provisional", rendered: "Bed 11:00 PM · phone wakes 7:30 AM", file: "PhoneInTheOtherRoomApp/Views/PixelHomeDashboard.swift", symbol: "PixelHomeDashboardContent.scheduleLabel")
                ],
                warnings: coverageWarning
            )
        case .activeWindDown:
            return ScreenbookScenario(
                id: kind.rawValue,
                title: "Active Wind Down",
                description: "Home's production live journey frozen fifteen minutes into Wind Down.",
                surface: "iphone",
                journey: "night-watch",
                route: "home",
                state: "active-wind-down",
                tags: ["active", "wind-down", "phone-free"],
                fixtureVersion: 1,
                captureProfile: captureProfile,
                captureProvenance: "automated-simulator",
                dependencies: commonDependencies + [
                    "PhoneInTheOtherRoomApp/Views/HomeView.swift",
                    "PhoneInTheOtherRoomApp/Views/ActiveRunView.swift",
                    "PhoneInTheOtherRoomApp/Views/Components/NightJourneyView.swift",
                    "Shared/ActiveRunPresentation.swift",
                    "Shared/NightJourneyProgress.swift"
                ],
                copy: [
                    .stable(AppCopy.ActiveWindDown.cueEyebrow, file: "PhoneInTheOtherRoomApp/Views/ActiveRunView.swift", symbol: "ActiveRunView.phoneFreeCue"),
                    .provisional(id: "iphone.active.wind-down.headline.provisional", rendered: "The evening can get quieter now.", file: "Shared/ActiveRunPresentation.swift", symbol: "ActiveRunPresentation.headline"),
                    .provisional(id: "iphone.active.wind-down.subheadline.provisional", rendered: "Phone-free time until bedtime.", file: "Shared/ActiveRunPresentation.swift", symbol: "ActiveRunPresentation.subheadline"),
                    .provisional(id: "iphone.active.wind-down.exit.provisional", rendered: "End Wind Down early", file: "Shared/ActiveRunPresentation.swift", symbol: "ActiveRunPresentation.exit")
                ],
                warnings: coverageWarning
            )
        case .earlyEnd:
            return ScreenbookScenario(
                id: kind.rawValue,
                title: "Early Ending",
                description: "The factual production receipt after a primary Wind Down ends early.",
                surface: "iphone",
                journey: "night-watch",
                route: "home",
                state: "early-end",
                tags: ["receipt", "early-ending", "fresh-start"],
                fixtureVersion: 1,
                captureProfile: captureProfile,
                captureProvenance: "automated-simulator",
                dependencies: commonDependencies + [
                    "PhoneInTheOtherRoomApp/Views/HomeView.swift",
                    "PhoneInTheOtherRoomApp/Views/EarlyEndView.swift",
                    "PhoneInTheOtherRoomApp/Views/Components/NightWatchReceiptCard.swift"
                ],
                copy: [
                    .stable(AppCopy.EarlyEnd.eyebrow, file: "PhoneInTheOtherRoomApp/Views/EarlyEndView.swift", symbol: "EarlyEndView"),
                    .stable(AppCopy.EarlyEnd.title, file: "PhoneInTheOtherRoomApp/Views/EarlyEndView.swift", symbol: "EarlyEndView"),
                    .stable(AppCopy.EarlyEnd.doneButton, file: "PhoneInTheOtherRoomApp/Views/EarlyEndView.swift", symbol: "EarlyEndView"),
                    .provisional(id: "iphone.early-end.duration.provisional", rendered: "Your phone got a little time away. Tonight can simply be a fresh start.", authored: "{durationSummary} Tonight can simply be a fresh start.", file: "PhoneInTheOtherRoomApp/Views/EarlyEndView.swift", symbol: "EarlyEndView.minutesAwayText", parameters: ["durationSummary": "Your phone got a little time away."])
                ],
                warnings: coverageWarning
            )
        case .populatedFarm:
            return ScreenbookScenario(
                id: kind.rawValue,
                title: "Populated Farm",
                description: "The production Farm with a fixed flock, wool balance, and search history.",
                surface: "iphone",
                journey: "farm",
                route: "farm",
                state: "populated",
                tags: ["farm", "flock", "wool"],
                fixtureVersion: 2,
                captureProfile: captureProfile,
                captureProvenance: "automated-simulator",
                dependencies: commonDependencies + [
                    "PhoneInTheOtherRoomApp/Views/HomeView.swift",
                    "PhoneInTheOtherRoomApp/Views/FarmView.swift",
                    "PhoneInTheOtherRoomApp/Views/FarmPastureView.swift",
                    "Shared/FarmModels.swift",
                    "Shared/FarmEconomyRules.swift",
                    "Assets.xcassets/farm"
                ],
                copy: [
                    .stable(AppCopy.Farm.eyebrow, file: "PhoneInTheOtherRoomApp/Views/FarmView.swift", symbol: "FarmDashboardContent.header"),
                    .stable(AppCopy.Farm.title, file: "PhoneInTheOtherRoomApp/Views/FarmView.swift", symbol: "FarmDashboardContent.header"),
                    .stable(AppCopy.Farm.detail, file: "PhoneInTheOtherRoomApp/Views/FarmView.swift", symbol: "FarmDashboardContent.header"),
                    .provisional(id: "iphone.farm.wool-ready.provisional", rendered: "6 sheep are ready to shear.", authored: "{count} sheep are ready to shear.", file: "PhoneInTheOtherRoomApp/Views/FarmView.swift", symbol: "FarmDashboardContent.priorityCard", parameters: ["count": "6"])
                ],
                warnings: coverageWarning
            )
        }
    }

    private static let commonDependencies = [
        "PhoneInTheOtherRoomApp/Copy/AppCopyToken.swift",
        "PhoneInTheOtherRoomApp/Design/Theme.swift",
        "PhoneInTheOtherRoomApp/Design/PixelComponents.swift",
        "PhoneInTheOtherRoomApp/Screenbook/ScreenbookFixtures.swift",
        "PhoneInTheOtherRoomApp/Screenbook/ScreenbookRootView.swift"
    ]

    private static let coverageWarning = [
        "Phase 1 maps review-critical copy only. Remaining screenshot-visible strings are provisional until later catalogue work."
    ]
}
#endif
