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
          halo: Color(0xFF1B3466),
          exposure: 0.34,
          nightLights: 1.0,
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
      _night = await _decode('assets/textures/earth_night.png');
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

  void _atmosphere(Canvas canvas, Offset centre, double radius) {
    canvas.drawCircle(
      centre,
      radius * 1.13,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.transparent,
            sky.halo.withValues(alpha: 0.26),
            Colors.transparent,
          ],
          stops: const <double>[0.87, 0.94, 1],
        ).createShader(
          Rect.fromCircle(center: centre, radius: radius * 1.13),
        ),
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

    void push(
      (Offset, double, double, double) p,
    ) {
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
          ..filterQuality = FilterQuality.medium,
      );
    }

    canvas.restore();
  }

  /// Vertex colour for the daylit pass: brightness plus the day's tint.
  int _shade(double brightness) {
    final Color base = Color.lerp(
      Colors.white,
      sky.tint,
      sky.tintAmount,
    )!;
    final int r = (base.r * 255 * brightness).round().clamp(0, 255);
    final int g = (base.g * 255 * brightness).round().clamp(0, 255);
    final int b = (base.b * 255 * brightness).round().clamp(0, 255);
    return (0xFF << 24) | (r << 16) | (g << 8) | b;
  }

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
