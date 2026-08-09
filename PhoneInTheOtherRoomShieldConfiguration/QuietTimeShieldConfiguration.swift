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
        let subtitle = allowsBriefAccess
            ? "\(reflection)\n\nUse this app for about five minutes. Wind Down will then continue automatically."
            : reflection

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: UIColor(red: 0.035, green: 0.043, blue: 0.039, alpha: 1),
            icon: UIImage(systemName: "moon.stars.fill"),
            title: ShieldConfiguration.Label(
                text: "Ollie is keeping watch",
                color: UIColor(red: 0.92, green: 0.89, blue: 0.79, alpha: 1)
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitle,
                color: UIColor(red: 0.78, green: 0.77, blue: 0.71, alpha: 1)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Continue Wind Down",
                color: UIColor(red: 0.10, green: 0.11, blue: 0.09, alpha: 1)
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.88, green: 0.85, blue: 0.74, alpha: 1),
            secondaryButtonLabel: allowsBriefAccess
                ? ShieldConfiguration.Label(
                    text: "Use Briefly",
                    color: UIColor(red: 0.84, green: 0.83, blue: 0.77, alpha: 1)
                )
                : nil
        )
    }
}
