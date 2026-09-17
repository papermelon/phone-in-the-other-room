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
            value: "Make room for a quieter evening, overnight, and morning. Give your phone a place outside your bedroom, or keep it accessible nearby when you need it for communication or alerts."
        )
    }

    enum ConfiguredHome {
        static let quietStatement = AppCopyToken(
            id: "iphone.home.configured.quiet-statement",
            value: "Put your phone in its spot. Take this time for yourself."
        )
        static let startButton = AppCopyToken(
            id: "iphone.home.configured.start-button",
            value: "Put phone away"
        )
    }

    enum ActiveWindDown {
        static let cueEyebrow = AppCopyToken(
            id: "iphone.active.wind-down.cue-eyebrow",
            value: "WIND DOWN"
        )
    }

    enum EarlyEnd {
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
            value: "Tend your flock, gather wool, and help Ollie bring missing sheep home."
        )
    }
}
