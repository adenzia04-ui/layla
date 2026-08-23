import MapKit
import UIKit

/// The dimmed map behind the prayer-times widget.
///
/// Originally the app rendered this and passed it over — but that needed an App
/// Group, which a free Apple account cannot have. So the widget renders it
/// itself and caches the PNG in its *own* container, which needs no entitlement
/// at all.
///
/// Widget extensions have a tight memory ceiling, so this is deliberately
/// modest: a small image, points of interest off, buildings off, and rendered
/// at most once per location change. Everything is best-effort — if it fails or
/// times out, the widget falls back to the plain night-sky gradient and nobody
/// sees an error.
enum WidgetMap {

    /// Wide enough to read as "this region", never "this street". The widget
    /// sits on a home screen other people can see.
    private static let spanDegrees: CLLocationDegrees = 6

    private static var cacheURL: URL? {
        FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("noor_widget_map.png")
    }

    private static let latKey = "noor.widget.map.lat"
    private static let lngKey = "noor.widget.map.lng"

    /// Returns a cached map when it still matches roughly where we are,
    /// otherwise renders a new one.
    static func image(
        latitude: Double,
        longitude: Double
    ) async -> UIImage? {
        let defaults = UserDefaults.standard
        let cachedLat = defaults.double(forKey: latKey)
        let cachedLng = defaults.double(forKey: lngKey)

        let moved = CLLocation(latitude: cachedLat, longitude: cachedLng)
            .distance(
                from: CLLocation(latitude: latitude, longitude: longitude)
            ) / 1000

        if moved < 100, let cached = load() {
            return cached
        }

        guard let rendered = await render(
            latitude: latitude,
            longitude: longitude
        ) else {
            return load()
        }

        defaults.set(latitude, forKey: latKey)
        defaults.set(longitude, forKey: lngKey)
        save(rendered)
        return rendered
    }

    private static func render(
        latitude: Double,
        longitude: Double
    ) async -> UIImage? {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: latitude,
                longitude: longitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: spanDegrees,
                longitudeDelta: spanDegrees
            )
        )
        options.size = CGSize(width: 480, height: 240)
        options.traitCollection = UITraitCollection(userInterfaceStyle: .dark)
        options.showsBuildings = false
        options.pointOfInterestFilter = .excludingAll

        return await withCheckedContinuation { continuation in
            MKMapSnapshotter(options: options).start { snapshot, _ in
                continuation.resume(returning: snapshot?.image)
            }
        }
    }

    private static func load() -> UIImage? {
        guard
            let url = cacheURL,
            let data = try? Data(contentsOf: url)
        else { return nil }
        return UIImage(data: data)
    }

    private static func save(_ image: UIImage) {
        guard let url = cacheURL, let data = image.pngData() else { return }
        try? data.write(to: url, options: .atomic)
    }
}
