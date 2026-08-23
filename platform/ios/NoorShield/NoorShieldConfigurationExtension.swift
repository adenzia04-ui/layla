import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Replaces Apple's generic "restricted" screen with Noor's own, so a user who
/// opens Instagram during Maghrib sees why — in the app's own voice, in the
/// app's own colours.
///
/// This extension is optional: without it the shield still works, it just looks
/// like a system default. With it, the block reads as a reminder rather than a
/// punishment.
@available(iOS 16.0, *)
class NoorShieldConfigurationExtension: ShieldConfigurationDataSource {

    // The Layl palette, matching lib/core/theme/app_colors.dart.
    private let midnight = UIColor(
        red: 0.024, green: 0.051, blue: 0.106, alpha: 1
    )
    private let cream = UIColor(
        red: 0.965, green: 0.945, blue: 0.906, alpha: 1
    )
    private let mist = UIColor(
        red: 0.965, green: 0.945, blue: 0.906, alpha: 0.7
    )
    private let gold = UIColor(
        red: 0.851, green: 0.698, blue: 0.416, alpha: 1
    )

    private func noorShield() -> ShieldConfiguration {
        let prayer = NoorLock.activePrayerLabel

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: midnight,
            icon: UIImage(systemName: "moon.stars.fill"),
            title: ShieldConfiguration.Label(
                text: "It is time for \(prayer)",
                color: cream
            ),
            subtitle: ShieldConfiguration.Label(
                text: "This app is paused until you confirm your prayer in "
                    + "Noor, or until the window ends.",
                color: mist
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Close",
                color: midnight
            ),
            primaryButtonBackgroundColor: gold
        )
    }

    override func configuration(
        shielding application: Application
    ) -> ShieldConfiguration {
        noorShield()
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        noorShield()
    }

    override func configuration(
        shielding webDomain: WebDomain
    ) -> ShieldConfiguration {
        noorShield()
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        noorShield()
    }
}
