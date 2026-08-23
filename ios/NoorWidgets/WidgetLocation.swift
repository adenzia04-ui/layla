import CoreLocation
import Foundation

/// Location for the widget process.
///
/// WidgetKit hands an extension the device location when its Info.plist has
/// `NSWidgetWantsLocation`, reusing the authorisation the app already holds —
/// the user is never prompted twice.
///
/// The last fix is cached in the extension's *own* container (which needs no
/// entitlement, unlike an App Group) so a widget still renders sensible times
/// when a fix is slow or unavailable.
enum WidgetLocation {

    private static let latKey = "noor.widget.lat"
    private static let lngKey = "noor.widget.lng"
    private static let cityKey = "noor.widget.city"

    /// The freshest position available to the widget.
    ///
    /// `TimelineProviderContext` carries no location — that was wishful
    /// thinking on my part. What actually happens is that
    /// `NSWidgetWantsLocation` keeps CoreLocation's cached fix populated for
    /// the extension, reusing the authorisation the app already holds, and the
    /// widget reads it synchronously. No prompt, no waiting.
    static func current() -> (latitude: Double, longitude: Double, city: String) {
        guard let fix = CLLocationManager().location else { return cached }

        let previous = cached
        let latitude = fix.coordinate.latitude
        let longitude = fix.coordinate.longitude
        remember(latitude: latitude, longitude: longitude, city: nil)

        // Only worth a geocode when we have actually moved.
        let movedKm = CLLocation(
            latitude: previous.latitude,
            longitude: previous.longitude
        ).distance(from: fix) / 1000

        if movedKm > 25 || previous.city.isEmpty {
            refreshCity(latitude: latitude, longitude: longitude)
            return (latitude, longitude, previous.city)
        }
        return (latitude, longitude, previous.city)
    }

    /// Falls back to Makkah — a defensible default for a prayer app, and
    /// obviously "not your location" rather than quietly wrong.
    static var cached: (latitude: Double, longitude: Double, city: String) {
        let defaults = UserDefaults.standard
        let lat = defaults.double(forKey: latKey)
        let lng = defaults.double(forKey: lngKey)
        if lat == 0 && lng == 0 {
            return (21.4225, 39.8262, "Makkah")
        }
        return (lat, lng, defaults.string(forKey: cityKey) ?? "")
    }

    static func remember(
        latitude: Double,
        longitude: Double,
        city: String?
    ) {
        let defaults = UserDefaults.standard
        defaults.set(latitude, forKey: latKey)
        defaults.set(longitude, forKey: lngKey)
        if let city, !city.isEmpty {
            defaults.set(city, forKey: cityKey)
        }
    }

    /// Reverse-geocodes in the background and caches the name. Best-effort:
    /// the widget renders with whatever it already has rather than waiting.
    static func refreshCity(latitude: Double, longitude: Double) {
        CLGeocoder().reverseGeocodeLocation(
            CLLocation(latitude: latitude, longitude: longitude)
        ) { marks, _ in
            guard let mark = marks?.first else { return }
            let name = mark.locality
                ?? mark.subAdministrativeArea
                ?? mark.administrativeArea
                ?? mark.country
            remember(latitude: latitude, longitude: longitude, city: name)
        }
    }
}
