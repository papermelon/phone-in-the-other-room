extension SlumberPartyCheerFeedback {
    var presentation: SlumberPartyCheerPresentation {
        let noun = switch cheer {
        case .warmWave: "warm wave"
        case .moonGlow: "moon glow"
        case .pawPrint: "paw print"
        }
        let message = count == 1
            ? "Your Slumber Party sent a \(noun)."
            : "Your Slumber Party sent \(count) \(noun)s."
        let symbol = switch cheer {
        case .warmWave: "hand.wave.fill"
        case .moonGlow: "moon.stars.fill"
        case .pawPrint: "pawprint.fill"
        }
        return SlumberPartyCheerPresentation(
            symbol: symbol,
            message: message
        )
    }
}

struct SlumberPartyCheerPresentation: Equatable, Sendable {
    var symbol: String
    var message: String
}
