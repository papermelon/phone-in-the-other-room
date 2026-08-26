import ManagedSettings
import ManagedSettingsUI
import UIKit

final class QuietTimeShieldConfiguration: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        quietTimeConfiguration(allowsBriefAccess: true)
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        quietTimeConfiguration(allowsBriefAccess: true)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        quietTimeConfiguration(allowsBriefAccess: false)
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        quietTimeConfiguration(allowsBriefAccess: false)
    }

    private func quietTimeConfiguration(allowsBriefAccess: Bool) -> ShieldConfiguration {
        let now = Date()
        let snapshot = presentationSnapshot
        let role = snapshot?.role ?? .primaryWindDown
        let group = snapshot?.cueGroup(at: now) ?? .windDown
        let defaultCue = ShieldCueCatalog.cue(
            for: group,
            runID: snapshot?.runID,
            date: now
        )
        let cue = purposeCue(for: snapshot)?.shieldText ?? defaultCue
        let tracker = briefAccessTrackerSummary(for: snapshot?.runID)
        let subtitleText = snapshot?.protectedEndDate.map {
            "\(cue)\nEnds at \($0.formatted(date: .omitted, time: .shortened))\n\(tracker.subtitle)"
        } ?? "\(cue)\n\(tracker.subtitle)"
        let secondaryLabel = allowsBriefAccess
            ? ShieldConfiguration.Label(
                text: secondaryButtonTitle,
                color: UIColor(red: 0.84, green: 0.83, blue: 0.77, alpha: 1)
            )
            : nil
        let title = ShieldConfiguration.Label(
            text: "Ollie is keeping the flock quiet.",
            color: UIColor(red: 0.92, green: 0.89, blue: 0.79, alpha: 1)
        )
        let subtitle = ShieldConfiguration.Label(
            text: subtitleText,
            color: UIColor(red: 0.78, green: 0.77, blue: 0.71, alpha: 1)
        )
        let primary = ShieldConfiguration.Label(
            text: primaryButtonTitle(for: role),
            color: UIColor(red: 0.10, green: 0.11, blue: 0.09, alpha: 1)
        )
        let background = UIColor(red: 0.035, green: 0.043, blue: 0.039, alpha: 1)
        let buttonBackground = UIColor(red: 0.88, green: 0.85, blue: 0.74, alpha: 1)

        if #available(iOS 26.4, *), allowsBriefAccess {
            return ShieldConfiguration(
                backgroundBlurStyle: nil,
                backgroundColor: background,
                icon: ollieIcon,
                title: title,
                subtitle: subtitle,
                primaryButtonLabel: primary,
                primaryButtonBackgroundColor: buttonBackground,
                secondaryButtonLabel: secondaryLabel,
                secondaryButtonSubmenuItems: secondarySubmenuItems(for: role)
            )
        }

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: background,
            icon: ollieIcon,
            title: title,
            subtitle: subtitle,
            primaryButtonLabel: primary,
            primaryButtonBackgroundColor: buttonBackground,
            secondaryButtonLabel: secondaryLabel
        )
    }

    private var presentationSnapshot: QuietTimeShieldPresentationSnapshot? {
        guard let defaults = UserDefaults(
            suiteName: QuietTimeShieldPresentationStorage.appGroupIdentifier
        ) else {
            return nil
        }
        return QuietTimeShieldPresentationSnapshot.load(from: defaults)
    }

    private func briefAccessTrackerSummary(for runID: UUID?) -> QuietTimeBriefAccessTrackerSummary {
        guard let defaults = UserDefaults(
            suiteName: QuietTimeShieldPresentationStorage.appGroupIdentifier
        ) else {
            return QuietTimeBriefAccessTrackerSummary()
        }
        return QuietTimeBriefAccessTrackerSummary.load(for: runID, from: defaults)
    }

    private func purposeCue(for snapshot: QuietTimeShieldPresentationSnapshot?) -> QuietPurposeCue? {
        guard let snapshot,
              let defaults = UserDefaults(
                  suiteName: QuietTimeShieldPresentationStorage.appGroupIdentifier
              ),
              let cue = QuietPurposeCueState.load(from: defaults),
              cue.occurrenceID == snapshot.runID,
              cue.revision == snapshot.registryRevision,
              cue.epoch == snapshot.registryEpoch else { return nil }
        return cue.cue
    }

    private var ollieIcon: UIImage {
        if let image = UIImage(
            named: "ollie_sheep_storybook_shield",
            in: Bundle(for: QuietTimeShieldConfiguration.self),
            compatibleWith: nil
        ) {
            return image.withRenderingMode(.alwaysOriginal)
        }
        if let image = UIImage(
            named: "dog_run_frame_01",
            in: Bundle(for: QuietTimeShieldConfiguration.self),
            compatibleWith: nil
        ) {
            return image.withRenderingMode(.alwaysOriginal)
        }
        return UIImage(systemName: "pawprint.fill")?.withRenderingMode(.alwaysOriginal)
            ?? UIImage()
    }

    private func primaryButtonTitle(for role: QuietTimeShieldRole) -> String {
        switch role {
        case .primaryWindDown: return "Return to Wind Down"
        case .additionalQuiet: return "Return to Phone Away"
        case .screenFreeMorning: return "Return to Screen-Free Morning"
        }
    }

    private func secondarySubmenuItems(for role: QuietTimeShieldRole) -> [String] {
        if role == .additionalQuiet {
            return [
                "Read a book · Use 5 min",
                "Focus on work · Use 5 min",
                "Something else · Use 5 min"
            ]
        }
        if role == .screenFreeMorning {
            return [
                "Read a book · Use 5 min",
                "Something offline · Use 5 min",
                "Something else · Use 5 min"
            ]
        }
        return [
            "Prepare for sleep · Use 5 min",
            "Something offline · Use 5 min",
            "Something else · Use 5 min"
        ]
    }

    private var secondaryButtonTitle: String {
        if #available(iOS 26.4, *) {
            return "Use Briefly"
        }
        return "Use for 5 minutes"
    }
}
