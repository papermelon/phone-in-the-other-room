import Foundation

/// User-facing copy for Search Journal notes, completion receipts, and Barn arrival.
/// Internal type names stay `SheepSearch*`; these strings are what people read after
/// Wind Down or Phone Away has already finished, so they do not call the note a search
/// or a protected night.
enum SheepSearchPresentation {
    static func originLine(for outcome: SheepSearchOutcome, date: Date? = nil) -> String {
        let stamp = (date ?? outcome.createdAt).formatted(date: .abbreviated, time: .omitted)
        return "\(originLabel(for: outcome.origin)) · \(stamp)"
    }

    static func originLabel(for origin: SheepSearchOrigin) -> String {
        switch origin {
        case .starter: return "Welcome gift"
        case .onboardingPractice: return "Practice gift"
        case .windDown: return "After Wind Down"
        case .phoneBreak: return "After Phone Away"
        case .unspecified: return "Farm note"
        }
    }

    static func foundEyebrow(for origin: SheepSearchOrigin) -> String {
        switch origin {
        case .starter, .onboardingPractice:
            return "A WELCOME GIFT"
        case .windDown, .phoneBreak, .unspecified:
            return "OLLIE FOUND A MISSING SHEEP"
        }
    }

    static func foundHeadline(for origin: SheepSearchOrigin) -> String {
        switch origin {
        case .starter:
            return "Ollie left a welcome gift in the pasture."
        case .onboardingPractice:
            return "Practice brought a welcome gift home."
        case .windDown, .phoneBreak, .unspecified:
            return "Ollie found a missing sheep."
        }
    }

    static func trailHeadline(for origin: SheepSearchOrigin) -> String {
        switch origin {
        case .phoneBreak:
            return "Ollie kept a clue from Phone Away."
        case .windDown, .unspecified:
            return "Ollie kept a clue."
        case .starter, .onboardingPractice:
            return "This welcome gift is waiting in Search Journal."
        }
    }

    static func trailBody(for origin: SheepSearchOrigin) -> String {
        switch origin {
        case .phoneBreak:
            return "Ollie did not bring a sheep home this time. The clue is saved for another Phone Away."
        case .windDown, .unspecified:
            return "Ollie did not bring a sheep home this time. The clue is saved for another night."
        case .starter, .onboardingPractice:
            return "Welcome gifts are recorded here so the Farm can remember how they arrived."
        }
    }

    static func openedByLine(for origin: SheepSearchOrigin) -> String {
        switch origin {
        case .starter:
            return "A welcome gift for a new Farm"
        case .onboardingPractice:
            return "A welcome gift from practice"
        case .windDown:
            return "After this Wind Down"
        case .phoneBreak:
            return "After \(PhoneAwaySearchMeter.maximumMinutes) Phone Away minutes"
        case .unspecified:
            return "Saved in Search Journal"
        }
    }

    static func barnArrivalLabel(for origin: SheepSearchOrigin) -> String {
        originLabel(for: origin)
    }

    static func completionLinkTitle(for origin: SheepSearchOrigin) -> String {
        switch origin {
        case .starter, .onboardingPractice:
            return "See the welcome gift"
        case .windDown, .phoneBreak, .unspecified:
            return "Open Search Journal"
        }
    }

    static func completionLinkHint(for origin: SheepSearchOrigin) -> String {
        switch origin {
        case .starter, .onboardingPractice:
            return "Shows the welcome gift saved in Search Journal"
        case .phoneBreak:
            return "Shows the Search Journal note for this Phone Away"
        case .windDown, .unspecified:
            return "Shows the Search Journal note for this Wind Down"
        }
    }

    static func journalResultHeadline(for outcome: SheepSearchOutcome) -> String {
        if outcome.result == .found, let name = outcome.sheepID.flatMap(SheepCatalog.definition)?.name {
            switch outcome.origin {
            case .starter, .onboardingPractice:
                return "Welcome gift: \(name)"
            case .windDown, .phoneBreak, .unspecified:
                return "Ollie found \(name)"
            }
        }
        return outcome.origin == .phoneBreak ? "Ollie kept a Phone Away clue" : "Ollie kept a clue"
    }

    static func detailsHeading(for origin: SheepSearchOrigin) -> String {
        switch origin {
        case .starter, .onboardingPractice:
            return "WELCOME GIFT"
        case .windDown, .phoneBreak, .unspecified:
            return "HOW THEY ARRIVED"
        }
    }

    static func showsTrailMetrics(for origin: SheepSearchOrigin) -> Bool {
        origin == .windDown || origin == .phoneBreak
    }

    static func emptyJournalDetail(isPhoneAway: Bool) -> String {
        isPhoneAway
            ? "This Phone Away has no saved Search Journal note."
            : "This Wind Down has no saved Search Journal note."
    }
}
