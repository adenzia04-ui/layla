import Foundation
import SwiftUI

/// One prayer, as the widgets render it.
struct NoorPrayer: Identifiable, Hashable {
    let key: String
    let label: String
    let date: Date

    var id: String { key }

    /// SF Symbol per prayer, echoing the icons used inside the app.
    /// One glyph per prayer, chosen to read as the time of day rather than as
    /// a generic icon: Fajr is still dark with the sun below the horizon, Asr
    /// is the sun already low, Isha is night. Someone should be able to tell
    /// which prayer a row is from the shape alone, before reading the word.
    var symbol: String {
        switch key {
        case "fajr": return "sparkles"
        case "sunrise": return "sunrise.fill"
        case "dhuhr": return "sun.max.fill"
        case "asr": return "sun.min.fill"
        case "maghrib": return "sunset.fill"
        case "isha": return "moon.stars.fill"
        case "tahajjud": return "moon.zzz.fill"
        default: return "moon.fill"
        }
    }

    /// The tint that goes with it — dawn gold through midday, cooling to the
    /// blue-white of night.
    var tint: Color {
        switch key {
        case "fajr": return Layl.goldSoft
        case "sunrise": return Layl.gold
        case "dhuhr": return Layl.gold
        case "asr": return Layl.ember
        case "maghrib": return Layl.ember
        case "isha": return Layl.cream
        default: return Layl.mist
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

    /// Bearing to the Kaaba from here, clockwise from true north.
    ///
    /// Computed in the widget from the same vendored Adhan sources the app
    /// uses, so the two cannot disagree about which way to face.
    var qiblaBearing: Double {
        Qibla(
            coordinates: Coordinates(latitude: latitude, longitude: longitude)
        ).direction
    }

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
        // Sunrise is not a prayer, and is listed anyway: it closes Fajr, and a
        // timetable that jumps from Fajr to Dhuhr reads as if a row is missing.
        ("sunrise", "Shurooq", .sunrise),
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

        // Shurooq is shown in the timetable but is never "next": nobody is
        // waiting to pray it, and a countdown labelled Shurooq would be
        // counting down to nothing you have to do.
        var next = list.first { $0.date > now && $0.key != "sunrise" }
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

        let current = list.last {
            $0.date <= now && $0.key != next.key && $0.key != "sunrise"
        }

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
    ///
    /// Not Makkah any more. Times are always drawn in the *device's* timezone,
    /// so Makkah's Fajr on a Malaysian clock rendered as "9:48 AM" — correct
    /// arithmetic, nonsense to read, and the first thing anyone sees of this
    /// widget is the gallery. The last known fix is used when there is one,
    /// and failing that a point on the device's own meridian, which produces
    /// times that at least belong to the day the reader is having.
    static var placeholder: NoorSnapshot {
        let cached = WidgetLocation.cached
        let known = !(cached.latitude == 0 && cached.longitude == 0)
            && cached.city != "Makkah"

        let hours = Double(TimeZone.current.secondsFromGMT()) / 3600
        let lat = known ? cached.latitude : 3.0
        let lng = known ? cached.longitude : hours * 15
        let name = known && !cached.city.isEmpty ? cached.city : "Your location"

        return compute(
            latitude: lat,
            longitude: lng,
            city: name,
            params: {
                var p = CalculationMethod.muslimWorldLeague.params
                p.madhab = .shafi
                return p
            }()
        ) ?? NoorSnapshot(
            city: name,
            hijri: hijriString(for: Date()),
            latitude: lat,
            longitude: lng,
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
