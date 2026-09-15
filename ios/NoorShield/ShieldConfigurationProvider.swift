import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen someone actually meets when an app is paused.
///
/// iOS draws the shield itself, from a separate process, and the only way to
/// change a word of it is an extension like this one. Left alone it says
/// "Restricted — you cannot use Snapchat because it is restricted", which is
/// true, anonymous, and slightly alarming: nothing on it says which app did
/// this, why, or when it ends. Someone who forgot they set this up would
/// reasonably think their phone had broken.
///
/// So: the mark, the name, the prayer, and the fact that it lifts on its own.
class ShieldConfigurationProvider: ShieldConfigurationDataSource {

    private var laylaShield: ShieldConfiguration {
        // Read fresh each time — the extension is spun up per shield, so this
        // is the only chance to learn which prayer is running.
        let prayer = NoorLock.activePrayerLabel

        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(
                red: 0.024, green: 0.051, blue: 0.106, alpha: 0.96
            ),
            icon: UIImage(named: "LaylaMark"),
            title: ShieldConfiguration.Label(
                text: prayer.isEmpty ? "Layla Pro" : "Layla Pro · \(prayer)",
                color: UIColor(red: 0.851, green: 0.698, blue: 0.416, alpha: 1)
            ),
            subtitle: ShieldConfiguration.Label(
                text: prayer.isEmpty
                    ? "Locked for prayer. Your apps come back on their own "
                        + "in 30 minutes. Nothing to undo."
                    : "Locked for \(prayer). Your apps come back on their own "
                        + "in 30 minutes. Nothing to undo.",
                color: UIColor(red: 0.965, green: 0.945, blue: 0.906, alpha: 0.75)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "OK",
                color: UIColor(red: 0.024, green: 0.051, blue: 0.106, alpha: 1)
            ),
            primaryButtonBackgroundColor: UIColor(
                red: 0.851, green: 0.698, blue: 0.416, alpha: 1
            )
        )
    }

    override func configuration(
        shielding application: Application
    ) -> ShieldConfiguration {
        laylaShield
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        laylaShield
    }

    override func configuration(
        shielding webDomain: WebDomain
    ) -> ShieldConfiguration {
        laylaShield
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        laylaShield
    }
}
