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

        // Whatever is cached is shown; a rebuild that waits on a map render
        // is a rebuild WidgetKit may kill, and a killed rebuild is a blank
        // widget. The map is only redrawn when the phone has really moved.
        if let cached = load() {
            if moved < 100 { return cached }
            Task.detached(priority: .background) {
                if let fresh = await render(latitude: latitude, longitude: longitude) {
                    defaults.set(latitude, forKey: latKey)
                    defaults.set(longitude, forKey: lngKey)
                    save(fresh)
                }
            }
            return cached
        }

        guard let rendered = await render(
            latitude: latitude,
            longitude: longitude
        ) else {
            return nil
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

        // Five seconds, then give up: the widget's own budget is shorter than
        // a map render on a sleepy network, and a missing map only means the
        // painted sky shows instead.
        return await withTaskGroup(of: UIImage?.self) { group in
            group.addTask {
                await withCheckedContinuation { continuation in
                    MKMapSnapshotter(options: options).start { snapshot, _ in
                        continuation.resume(returning: snapshot?.image)
                    }
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
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
