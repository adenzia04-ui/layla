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

    /// The globe frame the app last drew, if it has drawn one.
    var globeImage: UIImage?
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
            shared: NoorSharedStore.read(),
            globeImage: NoorSharedStore.readGlobe()
                .flatMap(UIImage.init(data:))
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

        // Wake at each remaining prayer boundary for a week, plus a
        // backstop. A timeline that ended at Isha left nothing to show for
        // someone who slept through the night and woke at Maghrib: WidgetKit
        // had to rebuild from scratch, and a rebuild it killed for taking too
        // long was a blank widget.
        // A week of boundaries. WidgetKit needs a finite list, so this is as
        // near to "always" as it allows: a phone can sit untouched for days
        // and still have a correct entry to show when it wakes, and the
        // rollover at the end of the list starts the next week.
        var dates = snapshot.prayers.map(\.date).filter { $0 > now }
        for day in 1...6 {
            let later = build(configuration, context, now: now.addingTimeInterval(Double(day) * 86_400))
            dates += later.prayers.map(\.date).filter { $0 > now }
        }
        dates.append(now.addingTimeInterval(60 * 60 * 6))

        // Decoded once, not per entry: seven timeline entries each holding
        // their own copy of the same PNG is how a widget gets itself killed
        // for memory.
        let globe = NoorSharedStore.readGlobe().flatMap(UIImage.init(data:))

        // Each entry carries the snapshot for its own moment, so an entry after
        // midnight knows tomorrow's Fajr is next rather than yesterday's Isha.
        let entries = ([now] + dates.sorted().prefix(48)).map { date in
            NoorEntry(
                date: date,
                snapshot: date == now ? snapshot : build(configuration, context, now: date),
                mapImage: map,
                shared: shared,
                globeImage: globe
            )
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    /// Uses the location WidgetKit provides when available, falling back to the
    /// last one we cached so a slow fix never blanks the widget.
    private func build(
        _ configuration: NoorWidgetConfig,
        _ context: Context,
        now: Date = Date()
    ) -> NoorSnapshot {
        // The app's own fix first — see NoorSharedStore.State.latitude.
        let shared = NoorSharedStore.read()
        let place: (latitude: Double, longitude: Double, city: String) = {
            if let s = shared, s.latitude != 0 || s.longitude != 0 {
                return (s.latitude, s.longitude, s.city)
            }
            return WidgetLocation.current()
        }()

        return NoorSnapshot.compute(
            latitude: place.latitude,
            longitude: place.longitude,
            city: place.city.isEmpty ? "Your location" : place.city,
            params: configuration.calculationParameters,
            now: now
        ) ?? .placeholder
    }
}
