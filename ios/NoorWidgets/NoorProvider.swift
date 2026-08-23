import CoreLocation
import UIKit
import WidgetKit

struct NoorEntry: TimelineEntry {
    let date: Date
    let snapshot: NoorSnapshot

    /// Nil until a map has been rendered — the widget falls back to its plain
    /// night-sky gradient, which is a perfectly good background on its own.
    var mapImage: UIImage?

    /// Whatever the app last published through the App Group. Nil on a fresh
    /// install, or when nobody has signed in — widgets must still render.
    var shared: NoorSharedStore.State?
}

/// Timeline provider for every Noor widget.
///
/// Entries are deliberately sparse. Countdowns render with SwiftUI's
/// `Text(timerInterval:)`, which ticks without waking the extension, so the
/// only reason to schedule a new entry is a prayer *boundary* — the moment the
/// highlighted prayer changes. Refreshing every minute would spend the widget's
/// budget redrawing identical pixels.
struct NoorProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> NoorEntry {
        NoorEntry(date: Date(), snapshot: .placeholder)
    }

    func snapshot(
        for configuration: NoorWidgetConfig,
        in context: Context
    ) async -> NoorEntry {
        let snapshot = build(configuration, context)
        return NoorEntry(
            date: Date(),
            snapshot: snapshot,
            mapImage: await WidgetMap.image(
                latitude: snapshot.latitude,
                longitude: snapshot.longitude
            ),
            shared: NoorSharedStore.read()
        )
    }

    func timeline(
        for configuration: NoorWidgetConfig,
        in context: Context
    ) async -> Timeline<NoorEntry> {
        let snapshot = build(configuration, context)
        let map = await WidgetMap.image(
            latitude: snapshot.latitude,
            longitude: snapshot.longitude
        )
        let shared = NoorSharedStore.read()
        let now = Date()

        // Wake at each remaining prayer boundary, plus a backstop so the widget
        // recovers even on a day the app is never opened.
        var dates = snapshot.prayers.map(\.date).filter { $0 > now }
        dates.append(now.addingTimeInterval(60 * 60 * 6))

        let entries = ([now] + dates.sorted().prefix(6)).map {
            NoorEntry(
                date: $0,
                snapshot: snapshot,
                mapImage: map,
                shared: shared
            )
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    /// Uses the location WidgetKit provides when available, falling back to the
    /// last one we cached so a slow fix never blanks the widget.
    private func build(
        _ configuration: NoorWidgetConfig,
        _ context: Context
    ) -> NoorSnapshot {
        let place = WidgetLocation.current()

        return NoorSnapshot.compute(
            latitude: place.latitude,
            longitude: place.longitude,
            city: place.city.isEmpty ? "Your location" : place.city,
            params: configuration.calculationParameters
        ) ?? .placeholder
    }
}
