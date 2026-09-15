import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../theme/app_colors.dart';
import '../../features/prayer_times/domain/prayer.dart';

/// How the globe is lit at a given point in the day.
@immutable
class GlobeSky {
  const GlobeSky({
    required this.tint,
    required this.tintAmount,
    required this.rim,
    required this.halo,
    required this.exposure,
    required this.nightLights,
    this.stars = false,
  });

  /// Warms or cools the daylit surface.
  final Color tint;
  final double tintAmount;

  /// The lit edge.
  final Color rim;

  /// Atmospheric bloom beyond the rim.
  final Color halo;

  /// Overall brightness of the day texture.
  final double exposure;

  /// How strongly the city-lights layer shows through.
  final double nightLights;

  /// Whether to scatter a starfield behind the planet. Isha only — by then the
  /// sky is dark enough for stars to be the truth rather than decoration.
  final bool stars;

  /// The globe tracks the sky outside: gold and low at Maghrib, dark with
  /// city lights at Isha, cool blue at Fajr.
  static GlobeSky forPrayer(PrayerId? prayer) {
    switch (prayer) {
      case PrayerId.fajr:
        return const GlobeSky(
          tint: Color(0xFF6E9BE0),
          tintAmount: 0.34,
          rim: Color(0xFFBFD4F2),
          halo: Color(0xFF2B5AA0),
          exposure: 0.62,
          nightLights: 0.55,
        );
      case PrayerId.sunrise:
      case PrayerId.dhuhr:
        return const GlobeSky(
          tint: Color(0xFFFFF0D0),
          tintAmount: 0.12,
          rim: Color(0xFFFDEBC0),
          halo: Color(0xFF7FB6E8),
          exposure: 1.0,
          nightLights: 0.0,
        );
      case PrayerId.asr:
        return const GlobeSky(
          tint: Color(0xFFFFE0B0),
          tintAmount: 0.20,
          rim: Color(0xFFDCEEFB),
          halo: Color(0xFF3E8FD4),
          exposure: 0.90,
          nightLights: 0.0,
        );
      case PrayerId.maghrib:
        // Named specifically in the brief — gold, low and warm.
        return const GlobeSky(
          tint: Color(0xFFFFA84B),
          tintAmount: 0.52,
          rim: Color(0xFFFFD98A),
          halo: Color(0xFFE0601C),
          exposure: 0.72,
          nightLights: 0.35,
        );
      case PrayerId.isha:
      case PrayerId.tahajjud:
      case null:
        return const GlobeSky(
          tint: Color(0xFF2C4A80),
          tintAmount: 0.55,
          rim: Color(0xFF9FB6D8),
          // Brighter and bluer, so the limb glows the way it does from orbit
          // rather than sitting flat against the night.
          halo: Color(0xFF4C7FD6),
          exposure: 0.34,
          nightLights: 1.0,
          stars: true,
        );
    }
  }
}

/// A slowly turning, photographic Earth.
///
/// NASA's Blue Marble is mapped onto a sphere with `drawVertices`: a lat/long
/// mesh is rotated and projected in Dart, back faces are culled, and the
/// texture is applied through an [ui.ImageShader]. Per-vertex colours carry
/// the lighting, so the day/night terminator and the time-of-day tint come
/// free rather than needing a fragment shader.
///
/// A second pass adds Black Marble city lights on the night side.
class NoorGlobe extends StatefulWidget {
  const NoorGlobe({
    super.key,
    this.prayer,
    this.latitude,
    this.longitude,
    this.period = const Duration(seconds: 140),
    this.radiusFactor = 0.60,
    this.centreY = 0.60,
  });

  final PrayerId? prayer;

  /// Where the user is. A marker rides the surface and turns out of view.
  final double? latitude;
  final double? longitude;

  /// One full turn. Deliberately slow — this is ambience, not a spinner.
  final Duration period;

  /// Sphere radius as a fraction of the box width, and the centre's height as
  /// a fraction of the box height.
  ///
  /// These exist so the box can be made taller — to let content sit over the
  /// Earth — without the planet sliding down with it. Grow the box and lower
  /// [centreY] by the same amount to hold the framing still.
  final double radiusFactor;
  final double centreY;

  /// Decodes the Earth textures ahead of time.
  ///
  /// Worth calling at startup so the globe never appears as a flat disc while
  /// two 2048×1024 images decode. Tests need it too — image decoding is real
  /// async, which a widget test's fake clock will not advance.
  static Future<void> preload() => _NoorGlobeState._ensureLoaded();

  /// The decoded Earth textures, for anything else that draws a sphere —
  /// null until [preload] has finished. Decoded once for the whole app.
  static ({ui.Image? day, ui.Image? night}) get textures =>
      (day: _NoorGlobeState._day, night: _NoorGlobeState._night);

  @override
  State<NoorGlobe> createState() => _NoorGlobeState();
}

class _NoorGlobeState extends State<NoorGlobe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  static ui.Image? _day;
  static ui.Image? _night;
  static Future<void>? _loading;

  @override
  void initState() {
    super.initState();
    _ensureTextures();
  }

  /// Loaded once for the whole app — two decoded 2048×1024 images are not
  /// something to hold per widget.
  static Future<void> _ensureLoaded() {
    if (_day != null) return Future<void>.value();
    return _loading ??= () async {
      _day = await _decode('assets/textures/earth_day.jpg');
      _night = await _decode('assets/textures/earth_night.jpg');
    }();
  }

  void _ensureTextures() {
    if (_day != null) return;
    _ensureLoaded().whenComplete(() {
      if (mounted) setState(() {});
    });
  }

  static Future<ui.Image> _decode(String asset) async {
    final ByteData data = await rootBundle.load(asset);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
    );
    return (await codec.getNextFrame()).image;
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui.Image? day = _day;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _spin,
        builder: (BuildContext context, Widget? child) => CustomPaint(
          painter: _GlobePainter(
            day: day,
            night: _night,
            turn: _spin.value,
            sky: GlobeSky.forPrayer(widget.prayer),
            latitude: widget.latitude,
            longitude: widget.longitude,
            radiusFactor: widget.radiusFactor,
            centreY: widget.centreY,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

/// Renders one frame of the globe to PNG bytes, for the home-screen widget.
///
/// The widget extension cannot draw this itself: the globe is a textured mesh
/// built by Flutter's renderer from two JPEGs in the app bundle, and a widget
/// gets neither the renderer nor the bundle. So the app draws a frame and
/// hands the picture over the App Group, the same division of labour the map
/// already uses.
///
/// [turn] is a full rotation over 0..1. The caller passes the fraction of the
/// day elapsed rather than an animation value, so the globe a widget shows is
/// turned to match the actual hour — it drifts through the day instead of
/// looping every 140 seconds, which is the only kind of movement a widget can
/// honestly have.
Future<Uint8List?> renderGlobeFrame({
  required double size,
  required double turn,
  PrayerId? prayer,
  double? latitude,
  double? longitude,
}) async {
  await _NoorGlobeState._ensureLoaded();
  final ui.Image? day = _NoorGlobeState._day;
  if (day == null) return null;

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  _GlobePainter(
    day: day,
    night: _NoorGlobeState._night,
    turn: turn,
    sky: GlobeSky.forPrayer(prayer),
    latitude: latitude,
    longitude: longitude,
    // Bigger and centred, because in the widget the globe is the ground the
    // text sits on rather than an ornament under a column of cards.
    radiusFactor: 0.78,
    centreY: 0.5,
  ).paint(canvas, Size(size, size));

  final ui.Image image = await recorder.endRecording().toImage(
    size.round(),
    size.round(),
  );
  final ByteData? bytes = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  image.dispose();
  return bytes?.buffer.asUint8List();
}

class _GlobePainter extends CustomPainter {
  _GlobePainter({
    required this.day,
    required this.night,
    required this.turn,
    required this.sky,
    this.latitude,
    this.longitude,
    this.radiusFactor = 0.60,
    this.centreY = 0.60,
  });

  final ui.Image? day;
  final ui.Image? night;
  final double turn;
  final GlobeSky sky;
  final double? latitude;
  final double? longitude;
  final double radiusFactor;
  final double centreY;

  /// Mesh resolution. 72×36 quads is smooth at phone sizes; finer just costs
  /// vertices nobody can see.
  static const int _cols = 72;
  static const int _rows = 36;

  /// Tilt, so the poles are not dead-on and the spin reads as a globe.
  static const double _tilt = 0.34;

  /// Sun direction in view space — slightly to the left and above, which puts
  /// the terminator where it looks natural rather than dead centre.
  static final _V3 _sun = const _V3(-0.55, 0.28, 0.79).normalised();

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width * radiusFactor;
    final Offset centre = Offset(size.width / 2, size.height * centreY);

    if (sky.stars) {
      _stars(canvas, size, centre, radius);
      // Before the atmosphere and the sphere, so the planet occludes a streak
      // that runs behind it instead of it skating over the surface.
      _meteor(canvas, size, centre, radius);
    }
    _atmosphere(canvas, centre, radius);

    final ui.Image? texture = day;
    if (texture == null) {
      // Textures still decoding — a plain sphere rather than a hole.
      canvas.drawCircle(
        centre,
        radius,
        Paint()..color = Color.lerp(sky.halo, AppColors.midnight, 0.65)!,
      );
    } else {
      _sphere(canvas, centre, radius, texture, night);
    }

    _marker(canvas, centre, radius);
    _rim(canvas, centre, radius);
  }

  /// A fixed scatter of stars behind the planet.
  ///
  /// Generated once from a fixed seed and held in a static: the painter runs
  /// every frame to turn the globe, and re-rolling the positions each time
  /// would make the whole sky crawl. Real stars do not move; the Earth does.
  static final List<({Offset at, double r, double alpha})> _starField =
      _makeStars();

  static List<({Offset at, double r, double alpha})> _makeStars() {
    // Jittered grid rather than uniform random. Random points over an area
    // this tall clump and leave bald patches — the first attempt put nothing
    // at all in the top hundred pixels, which is exactly the strip of sky the
    // dashboard actually shows.
    final math.Random rng = math.Random(20260822);
    const int cols = 14;
    const int rows = 30;
    final List<({Offset at, double r, double alpha})> out =
        <({Offset at, double r, double alpha})>[];
    for (int gy = 0; gy < rows; gy++) {
      for (int gx = 0; gx < cols; gx++) {
        // Not every cell gets one, or the grid becomes visible as a grid.
        if (rng.nextDouble() < 0.30) continue;
        final double roll = rng.nextDouble();
        out.add((
          at: Offset(
            (gx + rng.nextDouble()) / cols,
            (gy + rng.nextDouble()) / rows,
          ),
          r: roll > 0.90
              ? 1.0 + rng.nextDouble() * 0.8
              : 0.5 + rng.nextDouble() * 0.6,
          alpha: roll > 0.90
              ? 0.70 + rng.nextDouble() * 0.30
              : 0.40 + rng.nextDouble() * 0.35,
        ));
      }
    }
    return out;
  }

  void _stars(Canvas canvas, Size size, Offset centre, double radius) {
    final Paint paint = Paint();
    for (final ({Offset at, double r, double alpha}) star in _starField) {
      final Offset p = Offset(
        star.at.dx * size.width,
        star.at.dy * size.height,
      );
      // Only the planet itself is skipped. The bloom is translucent, so stars
      // behind it still show faintly — which is what fills the sky instead of
      // leaving a bare ring of black around the horizon.
      if ((p - centre).distance < radius * 0.99) continue;
      paint.color = AppColors.cream.withValues(alpha: star.alpha);
      canvas.drawCircle(p, star.r, paint);
    }
  }

  /// Streak slots per rotation. Seven across the 140-second spin puts a
  /// shooting star through roughly every twenty seconds — often enough to
  /// catch, rare enough to still feel like luck.
  ///
  /// Deliberately a division of the spin rather than a second controller:
  /// `turn` already wraps cleanly, so the sequence loops with no seam and the
  /// globe needs no extra clock to keep in step with.
  static const int _kMeteorSlots = 7;

  /// How much of a slot the streak is in flight. The remaining 92% is the empty
  /// sky that makes the arrival worth noticing.
  static const double _kMeteorFlight = 0.085;

  /// Three paths taking turns. Coordinates are x across the full width, y as a
  /// fraction of the sky strip above the globe — see [_meteor].
  static const List<({Offset from, Offset to, double tail, double width})>
  _meteorPaths = <({Offset from, Offset to, double tail, double width})>[
    (from: Offset(0.05, 0.14), to: Offset(0.44, 0.82), tail: 0.15, width: 1.6),
    (from: Offset(0.95, 0.20), to: Offset(0.56, 0.86), tail: 0.13, width: 1.4),
    (from: Offset(0.60, 0.06), to: Offset(0.93, 0.72), tail: 0.12, width: 1.3),
  ];

  /// One shooting star, drawn only while its slot is in flight.
  void _meteor(Canvas canvas, Size size, Offset centre, double radius) {
    // The globe is wider than the viewport, so "open sky" is not the whole
    // frame — it is the strip above the horizon. An earlier pass placed these
    // in viewport coordinates and the planet swallowed every one: at mid-flight
    // the head sat 220px from a centre with a 234px radius. Anchoring to the
    // strip keeps them clear of the disc whatever the framing.
    final double sky = centre.dy - radius;
    if (sky < 12) return;

    final double t = turn * _kMeteorSlots;
    final double f = t - t.floorToDouble();
    if (f > _kMeteorFlight) return;

    final ({Offset from, Offset to, double tail, double width}) path =
        _meteorPaths[t.floor() % _meteorPaths.length];
    final double p = f / _kMeteorFlight;

    // x spans the width; y is a fraction of the sky strip, not of the frame.
    final Offset a = Offset(path.from.dx * size.width, path.from.dy * sky);
    final Offset b = Offset(path.to.dx * size.width, path.to.dy * sky);
    final Offset run = b - a;
    final double len = run.distance;
    if (len < 1) return;

    // Decelerating — a meteor burns out, it does not coast to a stop.
    final double e = 1 - math.pow(1 - p, 1.7).toDouble();
    final Offset head = Offset.lerp(a, b, e)!;

    // Short on entry, longest mid-flight, gone by burnout. The same envelope
    // drives brightness, so the streak never blinks out at full strength.
    final double envelope = math.sin(math.pi * p).clamp(0.0, 1.0).toDouble();
    final Offset back =
        head - (run / len) * (path.tail * size.width * envelope);

    canvas.drawLine(
      back,
      head,
      Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = path.width
        ..shader = ui.Gradient.linear(back, head, <Color>[
          AppColors.cream.withValues(alpha: 0),
          AppColors.cream.withValues(alpha: envelope * 0.85),
        ]),
    );
    // A brighter grain at the head, so it reads as a point of light dragging a
    // trail rather than as a drawn line.
    canvas.drawCircle(
      head,
      path.width * 0.9,
      Paint()..color = AppColors.cream.withValues(alpha: envelope),
    );
  }

  void _atmosphere(Canvas canvas, Offset centre, double radius) {
    // A wide, many-stopped falloff rather than a narrow band.
    //
    // The old gradient ran from transparent to full and back inside 13% of the
    // radius, so the halo arrived and left too quickly to read as air — it drew
    // a ring with two visible edges. Air has no edges: this climbs from nothing
    // over half the radius and trails off past the horizon.
    final double reach = radius * 1.26;
    canvas.drawCircle(
      centre,
      reach,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.transparent,
            sky.halo.withValues(alpha: 0.03),
            sky.halo.withValues(alpha: 0.10),
            sky.halo.withValues(alpha: 0.20),
            sky.halo.withValues(alpha: 0.24),
            sky.halo.withValues(alpha: 0.13),
            sky.halo.withValues(alpha: 0.04),
            Colors.transparent,
          ],
          stops: const <double>[0.50, 0.64, 0.72, 0.777, 0.80, 0.88, 0.94, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: reach))
        // Softens whatever banding survives the stops — a gradient this gentle
        // quantises visibly on a dark background.
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.02),
    );
  }

  /// Builds the visible half of a lat/long mesh and draws it textured.
  void _sphere(
    Canvas canvas,
    Offset centre,
    double radius,
    ui.Image texture,
    ui.Image? lights,
  ) {
    final double angle = turn * 2 * math.pi;
    final double ca = math.cos(angle);
    final double sa = math.sin(angle);
    final double ct = math.cos(_tilt);
    final double st = math.sin(_tilt);

    final Float32List positions = Float32List(_cols * _rows * 12);
    final Float32List texCoords = Float32List(_cols * _rows * 12);
    final Int32List dayColours = Int32List(_cols * _rows * 6);
    final Int32List nightColours = Int32List(_cols * _rows * 6);
    int v = 0;
    int c = 0;

    final double tw = texture.width.toDouble();
    final double th = texture.height.toDouble();

    // Projects one grid corner; returns null when it faces away.
    (Offset, double, double, double)? corner(int row, int col) {
      final double u = col / _cols;
      final double vv = row / _rows;
      final double lon = (u - 0.5) * 2 * math.pi;
      final double lat = (0.5 - vv) * math.pi;
      final double cosLat = math.cos(lat);

      final double px = cosLat * math.sin(lon);
      final double py = math.sin(lat);
      final double pz = cosLat * math.cos(lon);

      final double x = px * ca - pz * sa;
      final double zs = px * sa + pz * ca;
      final double y = py * ct - zs * st;
      final double z = py * st + zs * ct;

      if (z < 0) return null;
      // Lambert term against the sun gives the terminator.
      final double lit = (x * _sun.x + y * _sun.y + z * _sun.z)
          .clamp(0.0, 1.0)
          .toDouble();
      return (centre + Offset(x * radius, -y * radius), u * tw, vv * th, lit);
    }

    void push((Offset, double, double, double) p) {
      positions[v] = p.$1.dx;
      texCoords[v] = p.$2;
      v++;
      positions[v] = p.$1.dy;
      texCoords[v] = p.$3;
      v++;

      // Daylight: a soft ramp so the terminator is a gradient, not an edge.
      final double lit = math.pow(p.$4, 0.55).toDouble();
      final double bright = (0.10 + lit * sky.exposure).clamp(0.0, 1.0);
      dayColours[c] = _shade(bright);
      nightColours[c] = _lightsShade(1 - lit);
      c++;
    }

    for (int row = 0; row < _rows; row++) {
      for (int col = 0; col < _cols; col++) {
        final a = corner(row, col);
        final b = corner(row, col + 1);
        final d = corner(row + 1, col);
        final e = corner(row + 1, col + 1);
        if (a == null || b == null || d == null || e == null) continue;

        push(a);
        push(b);
        push(d);
        push(b);
        push(e);
        push(d);
      }
    }

    if (v == 0) return;

    final ui.Vertices mesh = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.sublistView(positions, 0, v),
      textureCoordinates: Float32List.sublistView(texCoords, 0, v),
      colors: Int32List.sublistView(dayColours, 0, c),
    );

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: centre, radius: radius)),
    );

    canvas.drawVertices(
      mesh,
      BlendMode.modulate,
      Paint()
        ..shader = ui.ImageShader(
          texture,
          TileMode.clamp,
          TileMode.clamp,
          Matrix4.identity().storage,
        )
        ..filterQuality = FilterQuality.medium,
    );

    // City lights on the dark side.
    if (lights != null && sky.nightLights > 0.01) {
      final double lw = lights.width.toDouble();
      final double lh = lights.height.toDouble();
      final Float32List lightUv = Float32List(v);
      for (int i = 0; i < v; i += 2) {
        lightUv[i] = texCoords[i] / tw * lw;
        lightUv[i + 1] = texCoords[i + 1] / th * lh;
      }

      canvas.drawVertices(
        ui.Vertices.raw(
          ui.VertexMode.triangles,
          Float32List.sublistView(positions, 0, v),
          textureCoordinates: lightUv,
          colors: Int32List.sublistView(nightColours, 0, c),
        ),
        BlendMode.modulate,
        Paint()
          ..shader = ui.ImageShader(
            lights,
            TileMode.clamp,
            TileMode.clamp,
            Matrix4.identity().storage,
          )
          ..blendMode = BlendMode.plus
          ..colorFilter = _kCityLights
          ..filterQuality = FilterQuality.medium,
      );
    }

    canvas.restore();
  }

  /// Vertex colour for the daylit pass: brightness plus the day's tint.
  int _shade(double brightness) {
    final Color base = Color.lerp(Colors.white, sky.tint, sky.tintAmount)!;
    final int r = (base.r * 255 * brightness).round().clamp(0, 255);
    final int g = (base.g * 255 * brightness).round().clamp(0, 255);
    final int b = (base.b * 255 * brightness).round().clamp(0, 255);
    return (0xFF << 24) | (r << 16) | (g << 8) | b;
  }

  /// Gain and warmth for the city lights.
  ///
  /// The VIIRS night map is faint — its mean is 13/255 — so blended straight it
  /// reads as a grey smudge rather than the lit coastlines you see from orbit.
  /// This lifts it and pushes it amber, since sodium street lighting is warm
  /// and the neutral source renders cities a dead white.
  ///
  /// The offsets are not decoration. Open ocean in this image sits at 5, not 0,
  /// so a bare multiply would raise that floor to 13 and lay a grey film over
  /// every dark sea under an additive blend. Each row subtracts its own gain
  /// times that pedestal, putting unlit ground back at true black.
  static const ColorFilter _kCityLights = ColorFilter.matrix(<double>[
    2.60, 0, 0, 0, -13.0, //
    0, 2.10, 0, 0, -10.5, //
    0, 0, 1.35, 0, -6.75, //
    0, 0, 0, 1, 0, //
  ]);

  /// Vertex colour for the city-lights pass — only where the sun is not.
  int _lightsShade(double darkness) {
    final double a = (darkness * sky.nightLights).clamp(0.0, 1.0);
    final int level = (a * 255).round();
    return (0xFF << 24) | (level << 16) | (level << 8) | level;
  }

  /// Where the user is, riding the surface.
  void _marker(Canvas canvas, Offset centre, double radius) {
    final double? lat = latitude;
    final double? lon = longitude;
    if (lat == null || lon == null) return;

    final double phi = lat * math.pi / 180;
    final double theta = lon * math.pi / 180;
    final double cosPhi = math.cos(phi);
    final double px = cosPhi * math.sin(theta);
    final double py = math.sin(phi);
    final double pz = cosPhi * math.cos(theta);

    final double angle = turn * 2 * math.pi;
    final double x = px * math.cos(angle) - pz * math.sin(angle);
    final double zs = px * math.sin(angle) + pz * math.cos(angle);
    final double y = py * math.cos(_tilt) - zs * math.sin(_tilt);
    final double z = py * math.sin(_tilt) + zs * math.cos(_tilt);
    if (z < 0) return;

    final Offset at = centre + Offset(x * radius, -y * radius);
    canvas.drawCircle(
      at,
      radius * 0.034,
      Paint()..color = sky.rim.withValues(alpha: 0.20 * z),
    );
    canvas.drawCircle(
      at,
      radius * 0.013,
      Paint()..color = Colors.white.withValues(alpha: 0.95 * z),
    );
  }

  void _rim(Canvas canvas, Offset centre, double radius) {
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      math.pi * 1.08,
      math.pi * 0.84,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: <Color>[
            sky.rim.withValues(alpha: 0),
            sky.rim.withValues(alpha: 0.85),
            sky.rim.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: radius))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
    );
  }

  @override
  bool shouldRepaint(_GlobePainter old) =>
      old.turn != turn ||
      old.sky != sky ||
      old.day != day ||
      old.latitude != latitude ||
      old.longitude != longitude ||
      old.radiusFactor != radiusFactor ||
      old.centreY != centreY;
}

class _V3 {
  const _V3(this.x, this.y, this.z);
  final double x;
  final double y;
  final double z;

  _V3 normalised() {
    final double len = math.sqrt(x * x + y * y + z * z);
    return _V3(x / len, y / len, z / len);
  }
}
