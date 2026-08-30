#if DEBUG
import Foundation

/// A bounded Screenbook-only review cadence. It cannot affect normal DEBUG or
/// release launches because both a Screenbook request and this explicit flag
/// are required; it never writes the user's equipped cosmetic.
enum ScreenbookOllieMotionReview {
    static let reviewArgument = "-screenbook-ollie-motion-review"
    static let accessoryArgument = "-screenbook-ollie-motion-accessory"

    static var configuration: Configuration? {
        configuration(
            arguments: ProcessInfo.processInfo.arguments,
            isScreenbookLaunch: ScreenbookLaunchRequest.current != nil
        )
    }

    static func configuration(
        arguments: [String],
        isScreenbookLaunch: Bool
    ) -> Configuration? {
        guard isScreenbookLaunch,
              value(after: reviewArgument, in: arguments) == "YES" else {
            return nil
        }
        return Configuration(accessory: AccessorySelection(argument: value(after: accessoryArgument, in: arguments)))
    }

    private static func value(after argument: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: argument), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }

    struct Configuration: Equatable {
        let accessory: AccessorySelection

        /// 13.39 seconds total: short neutral holds for capture review, while
        /// keeping the production frame timings and five-second rest intact.
        let schedule = OllieCompanionAnimationSchedule(segments: [
            .init(.neutral, duration: 0.8),
            .init(.headTilt, duration: 1.2),
            .init(.neutral, duration: 0.8),
            .init(.earTuck, duration: 0.60),
            .init(.neutral, duration: 0.8),
            .init(.tongueGreeting, duration: 0.75),
            .init(.neutral, duration: 0.8),
            .init(.settleToRest, duration: 1.22),
            .init(.resting, duration: 5),
            .init(.rise, duration: 0.62),
            .init(.neutral, duration: 0.8)
        ])

        func accessoryItemID(default itemID: String?) -> String? {
            switch accessory {
            case .unchanged: itemID
            case .none: nil
            case let .item(itemID): itemID
            }
        }
    }

    enum AccessorySelection: Equatable {
        case unchanged
        case none
        case item(String)

        init(argument: String?) {
            switch argument {
            case "none": self = .none
            case "moss": self = .item("ollie_moss_bandana")
            case "moon": self = .item("ollie_moon_kerchief")
            case "bell": self = .item("ollie_brass_bell")
            default: self = .unchanged
            }
        }
    }
}
#endif
