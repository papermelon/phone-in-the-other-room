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
        let quote = ShieldQuoteCatalog.quote(for: Date())
        let reflection = "“\(quote.quote)”\n— \(quote.author), \(quote.source)"
        let secondaryLabel = allowsBriefAccess
            ? ShieldConfiguration.Label(
                text: secondaryButtonTitle,
                color: UIColor(red: 0.84, green: 0.83, blue: 0.77, alpha: 1)
            )
            : nil
        let title = ShieldConfiguration.Label(
            text: "Ollie is keeping watch",
            color: UIColor(red: 0.92, green: 0.89, blue: 0.79, alpha: 1)
        )
        let subtitle = ShieldConfiguration.Label(
            text: reflection,
            color: UIColor(red: 0.78, green: 0.77, blue: 0.71, alpha: 1)
        )
        let primary = ShieldConfiguration.Label(
            text: primaryButtonTitle,
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
                secondaryButtonSubmenuItems: [
                    "Use for about 5 minutes",
                    "Keep Wind Down"
                ]
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

    private var ollieIcon: UIImage {
        if let image = UIImage(
            named: "dog_storybook_run_frame_01",
            in: Bundle(for: QuietTimeShieldConfiguration.self),
            compatibleWith: nil
        ) {
            return image.withRenderingMode(.alwaysOriginal)
        }
        return UIImage(systemName: "pawprint.fill")?.withRenderingMode(.alwaysOriginal)
            ?? UIImage()
    }

    private var primaryButtonTitle: String {
        if #available(iOS 26.5, *) {
            return "Continue Wind Down"
        }
        return "Close this app"
    }

    private var secondaryButtonTitle: String {
        if #available(iOS 26.4, *) {
            return "Use Briefly"
        }
        return "Use for about 5 minutes"
    }
}
