import Foundation

struct AppCopyToken: Hashable {
    let id: String
    let value: String
}

enum AppCopy {
    enum OnboardingWelcome {
        static let eyebrow = AppCopyToken(
            id: "iphone.onboarding.welcome.eyebrow",
            value: "COUNTING SHEEP"
        )
        static let title = AppCopyToken(
            id: "iphone.onboarding.welcome.title",
            value: "Put the phone to bed before you."
        )
        static let detail = AppCopyToken(
            id: "iphone.onboarding.welcome.detail",
            value: "Counting Sheep helps you make a little space between your screen and your sleep — before bed, overnight, and after you wake."
        )
    }

    enum ConfiguredHome {
        static let quietStatement = AppCopyToken(
            id: "iphone.home.configured.quiet-statement",
            value: "The quiet is the point. There is nothing to check off."
        )
        static let startButton = AppCopyToken(
            id: "iphone.home.configured.start-button",
            value: "Start Wind Down"
        )
    }

    enum ActiveWindDown {
        static let cueEyebrow = AppCopyToken(
            id: "iphone.active.wind-down.cue-eyebrow",
            value: "PHONE-FREE WIND-DOWN"
        )
    }

    enum EarlyEnd {
        static let eyebrow = AppCopyToken(
            id: "iphone.early-end.receipt-eyebrow",
            value: "WIND DOWN ENDED"
        )
        static let title = AppCopyToken(
            id: "iphone.early-end.receipt-title",
            value: "Welcome back. Ollie kept your spot warm."
        )
        static let doneButton = AppCopyToken(
            id: "iphone.early-end.done-button",
            value: "Done for now"
        )
    }

    enum Farm {
        static let eyebrow = AppCopyToken(
            id: "iphone.farm.header-eyebrow",
            value: "THE FARM"
        )
        static let title = AppCopyToken(
            id: "iphone.farm.header-title",
            value: "Your flock, wool, and Ollie's finds"
        )
        static let detail = AppCopyToken(
            id: "iphone.farm.header-detail",
            value: "Wind Down grows the Farm. Choose what to do with your sheep, wool, and Ollie's next find."
        )
    }
}
