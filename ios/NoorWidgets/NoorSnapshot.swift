import Foundation
import SwiftUI

/// One prayer, as the widgets render it.
struct NoorPrayer: Identifiable, Hashable {
    let key: String
    let label: String
    let date: Date

    var id: String { key }

    /// SF Symbol per prayer, echoing the icons used inside the app.
    var symbol: String {
        switch key {
        case "fajr": return "sunrise"
        case "dhuhr": return "sun.max"
        case "asr": return "sun.min"
        case "maghrib": return "sunset"
        case "isha": return "moon.stars"
        default: return "moon"
        }
    }
}

/// Everything a widget draws — **computed in the widget process**, not handed
/// over by the app.
///
/// This is the whole reason the widgets work on a free Apple account. Sharing
/// data with an extension needs an App Group, which is a paid-membership
/// capability. Prayer times, though, are a pure function of location, date and
/// calculation method, and the widget can get all three by itself: location
/// from `NSWidgetWantsLocation`, method from its own configuration, and the
/// maths from the vendored Adhan sources — the Swift port of the very library
/// the Dart side uses, so the two cannot drift apart.
///
/// The one thing genuinely unavailable here is the streak, which lives in
/// Firestore behind the user's login. That appears in the Live Activity
/// instead, where the app passes state directly and no App Group is involved.
struct NoorSnapshot {
    let city: String
    let hijri: String
    let latitude: Double
    let longitude: Double
    let prayers: [NoorPrayer]
    let next: NoorPrayer
    let current: NoorPrayer?
    let tahajjudStart: Date?

    var nextDate: Date { next.date }
    var currentDate: Date { current?.date ?? next.date.addingTimeInterval(-8 * 3600) }
    var nextKey: String { next.key }
    var currentKey: String { current?.key ?? "" }
    var nextPrayer: NoorPrayer? { next }

    /// 0–1 across the gap between the running prayer and the next one — what
    /// the curved gauge fills.
    func progress(at now: Date = Date()) -> Double {
        let span = nextDate.timeIntervalSince(currentDate)
        guard span > 0 else { return 0 }
        return min(max(now.timeIntervalSince(currentDate) / span, 0), 1)
    }

    // MARK: - Building

    private static let order: [(key: String, label: String, prayer: Prayer)] = [
        ("fajr", "Fajr", .fajr),
        ("dhuhr", "Dhuhr", .dhuhr),
        ("asr", "Asr", .asr),
        ("maghrib", "Maghrib", .maghrib),
        ("isha", "Isha", .isha),
    ]

    /// Computes today's schedule, rolling forward to tomorrow's Fajr once Isha
    /// has begun so the countdown never reads a time in the past.
    static func compute(
        latitude: Double,
        longitude: Double,
        city: String,
        params: CalculationParameters,
        now: Date = Date()
    ) -> NoorSnapshot? {
        let coordinates = Coordinates(latitude: latitude, longitude: longitude)
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: now
        )

        guard
            let today = PrayerTimes(
                coordinates: coordinates,
                date: components,
                calculationParameters: params
            )
        else { return nil }

        var list: [NoorPrayer] = order.map { entry in
            NoorPrayer(
                key: entry.key,
                label: entry.label,
                date: today.time(for: entry.prayer)
            )
        }
        guard !list.isEmpty else { return nil }

        var next = list.first { $0.date > now }
        if next == nil {
            // Past Isha — the next prayer is tomorrow's Fajr.
            let tomorrow = calendar.dateComponents(
                [.year, .month, .day],
                from: calendar.date(byAdding: .day, value: 1, to: now) ?? now
            )
            if let t = PrayerTimes(
                coordinates: coordinates,
                date: tomorrow,
                calculationParameters: params
            ) {
                let fajr = NoorPrayer(
                    key: "fajr",
                    label: "Fajr",
                    date: t.time(for: .fajr)
                )
                next = fajr
                // Show tomorrow's Fajr in the strip rather than a stale one.
                list[0] = fajr
            }
        }
        guard let next else { return nil }

        let current = list.last { $0.date <= now && $0.key != next.key }

        return NoorSnapshot(
            city: city,
            hijri: hijriString(for: now),
            latitude: latitude,
            longitude: longitude,
            prayers: list,
            next: next,
            current: current,
            tahajjudStart: SunnahTimes(from: today)?.lastThirdOfTheNight
        )
    }

    static func hijriString(for date: Date) -> String {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.locale = Locale(identifier: "en")
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: date) + " AH"
    }

    /// Shown in the widget gallery, and before any location has arrived.
    static var placeholder: NoorSnapshot {
        compute(
            latitude: 21.4225,
            longitude: 39.8262,
            city: "Makkah",
            params: {
                var p = CalculationMethod.muslimWorldLeague.params
                p.madhab = .shafi
                return p
            }()
        ) ?? NoorSnapshot(
            city: "Makkah",
            hijri: hijriString(for: Date()),
            latitude: 21.4225,
            longitude: 39.8262,
            prayers: [],
            next: NoorPrayer(
                key: "fajr",
                label: "Fajr",
                date: Date().addingTimeInterval(3600)
            ),
            current: nil,
            tahajjudStart: nil
        )
    }
}
