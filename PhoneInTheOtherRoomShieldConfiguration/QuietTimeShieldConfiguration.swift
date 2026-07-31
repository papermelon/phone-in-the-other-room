import ManagedSettings
import ManagedSettingsUI
import UIKit

final class QuietTimeShieldConfiguration: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        quietTimeConfiguration()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        quietTimeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        quietTimeConfiguration()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        quietTimeConfiguration()
    }

    private func quietTimeConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemChromeMaterialDark,
            backgroundColor: nil,
            icon: UIImage(systemName: "moon.stars.fill"),
            title: ShieldConfiguration.Label(
                text: "Wind Down is resting here",
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: "You chose a little space away from this app. Open Counting Sheep if you need to end Wind Down.",
                color: UIColor.white.withAlphaComponent(0.82)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Return to quiet",
                color: .white
            ),
            primaryButtonBackgroundColor: UIColor.systemGreen,
            secondaryButtonLabel: nil
        )
    }
}
