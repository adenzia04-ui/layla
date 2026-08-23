import SwiftUI
import WidgetKit

/// Entry point for the widget extension.
///
/// **This file needs `@main` and must belong to the NoorWidgets target only** —
/// putting it in Runner as well gives you two `@main` symbols and a link error.
@main
struct NoorWidgetBundle: WidgetBundle {
    var body: some Widget {
        PrayerTimesWidget()
        PrayerArcWidget()
        NextPrayerWidget()
        PrayerLiveActivity()
    }
}
