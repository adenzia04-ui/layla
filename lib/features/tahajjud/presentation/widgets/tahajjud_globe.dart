import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/noor_globe.dart';
import '../../domain/tahajjud_presence.dart';

/// The Earth at night, in the hand.
///
/// The same photographic sphere as the home screen, but this one you can
/// turn — drag to rotate, pinch to come closer, tap a light to go to it —
/// with the night side lit by its cities and a field of stars behind. Every
/// light on it is someone praying Tahajjud about there, right now.
///
/// It goes as close as a photograph of the whole planet honestly can. Past
/// that the screen hands the same spot to the satellite map, which carries
/// the zoom the rest of the way down to streets; pinching back out on the
/// map returns here.
class TahajjudGlobe extends StatefulWidget {
  const TahajjudGlobe({
    super.key,
    required this.clusters,
    required this.onDetail,
    required this.onFocus,
    this.initialFocus,
  });

  final List<PresenceCluster> clusters;

  /// Pinched past the globe's detail: take this centre to the map.
  final ValueChanged<LatLng> onDetail;

  /// Where the middle of the globe is pointing, as it turns.
  final ValueChanged<LatLng> onFocus;

  final LatLng? initialFocus;

  /// The scale at which the globe hands over to the map.
  static const double handoff = 2.6;

  @override
  State<TahajjudGlobe> createState() => _TahajjudGlobeState();
}

class _TahajjudGlobeState extends State<TahajjudGlobe>
    with TickerProviderStateMixin {
  /// Rotation about the poles and tilt toward the viewer, in radians.
  late double _lon = -(widget.initialFocus?.longitude ?? 39.8) * math.pi / 180;
  late double _lat = (widget.initialFocus?.latitude ?? 21.4) * math.pi / 180;
  double _scale = 1;

  /// Turns the globe slowly while nobody is touching it.
  /// The glide after a flick: the globe keeps turning and slows the way a
  /// spun thing does, rather than stopping dead under the finger.
  late final AnimationController _spin = AnimationController.unbounded(
    vsync: this,
  )..addListener(_tickSpin);
  Size _lastSize = Size.zero;

  void _tickSpin() {
    _lastTouch = DateTime.now();
    setState(() {
      _lon = _spin.value;
      _report();
    });
  }

  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  /// The lights breathe.
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  /// Flies to a tapped light.
  late final AnimationController _fly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  Animation<double>? _flyLon;
  Animation<double>? _flyLat;
  Animation<double>? _flyScale;

  /// When each light first appeared, so it can bloom in.
  final Map<String, DateTime> _born = <String, DateTime>{};

  DateTime _lastTouch = DateTime.fromMillisecondsSinceEpoch(0);
  double _startLon = 0;
  double _startLat = 0;
  double _startScale = 1;
  Offset _startFocal = Offset.zero;
  bool _handedOff = false;

  /// Where the lights were last drawn, for tapping them.
  final List<(Offset, PresenceCluster)> _hits = <(Offset, PresenceCluster)>[];

  static const double _maxLat = 75 * math.pi / 180;

  @override
  void initState() {
    super.initState();
    NoorGlobe.preload().whenComplete(() {
      if (mounted) setState(() {});
    });
    _drift.addListener(_tickDrift);
    _fly.addListener(() {
      setState(() {
        _lon = _flyLon?.value ?? _lon;
        _lat = _flyLat?.value ?? _lat;
        _scale = _flyScale?.value ?? _scale;
      });
    });
  }

  @override
  void dispose() {
    _drift.dispose();
    _spin.dispose();
    _breath.dispose();
    _fly.dispose();
    super.dispose();
  }

  /// One frame of the idle drift: a full turn in about four minutes, only
  /// after a few seconds without a finger on it, and slower when zoomed.
  void _tickDrift() {
    if (DateTime.now().difference(_lastTouch) < const Duration(seconds: 4)) {
      return;
    }
    if (_fly.isAnimating || _spin.isAnimating) return;
    setState(() {
      _lon += (2 * math.pi / 240) / 60 / _scale;
      _report();
    });
  }

  void _report() {
    widget.onFocus(
      LatLng(_lat * 180 / math.pi, _wrapDeg(-_lon * 180 / math.pi)),
    );
  }

  double _wrapDeg(double d) {
    double x = d;
    while (x > 180) {
      x -= 360;
    }
    while (x < -180) {
      x += 360;
    }
    return x;
  }

  double _radius(Size size) =>
      math.min(size.width, size.height) * 0.42 * _scale;

  void _onStart(ScaleStartDetails d) {
    _fly.stop();
    _spin.stop();
    _lastTouch = DateTime.now();
    _startLon = _lon;
    _startLat = _lat;
    _startScale = _scale;
    _startFocal = d.focalPoint;
    _handedOff = false;
  }

  void _onUpdate(ScaleUpdateDetails d, Size size) {
    _lastTouch = DateTime.now();
    _lastSize = size;
    final double r = _radius(size);
    final Offset delta = d.focalPoint - _startFocal;
    setState(() {
      // A finger moves the surface under it: one radius of drag is about
      // a radian of turn, whatever the zoom.
      _lon = _startLon + delta.dx / r;
      _lat = (_startLat + delta.dy / r).clamp(-_maxLat, _maxLat);
      _scale = (_startScale * d.scale).clamp(1.0, TahajjudGlobe.handoff);
      _report();
    });
    if (_scale >= TahajjudGlobe.handoff - 0.001 && !_handedOff) {
      _handedOff = true;
      HapticFeedback.mediumImpact();
      widget.onDetail(
        LatLng(_lat * 180 / math.pi, _wrapDeg(-_lon * 180 / math.pi)),
      );
    }
  }

  void _onEnd(ScaleEndDetails d) {
    _lastTouch = DateTime.now();
    if (_lastSize == Size.zero || _handedOff) return;
    // Pixels per second across the surface become radians per second of
    // turn, then a friction glide: a quick flick carries the globe a good way
    // round, a gentle release barely moves it. Latitude does not glide — a
    // globe spins on its axis, it does not tumble.
    final double v = d.velocity.pixelsPerSecond.dx / _radius(_lastSize);
    if (v.abs() < 0.25) return;
    _spin.animateWith(FrictionSimulation(0.35, _lon, v.clamp(-6.0, 6.0)));
  }

  void _onDoubleTap() {
    _lastTouch = DateTime.now();
    if (_scale >= TahajjudGlobe.handoff - 0.3) {
      widget.onDetail(
        LatLng(_lat * 180 / math.pi, _wrapDeg(-_lon * 180 / math.pi)),
      );
      return;
    }
    _flyTo(_lon, _lat, (_scale * 1.6).clamp(1.0, TahajjudGlobe.handoff));
  }

  void _onTapUp(TapUpDetails d) {
    _lastTouch = DateTime.now();
    (Offset, PresenceCluster)? best;
    double bestD = 30;
    for (final (Offset p, PresenceCluster c) in _hits) {
      final double dist = (p - d.localPosition).distance;
      if (dist < bestD) {
        bestD = dist;
        best = (p, c);
      }
    }
    if (best == null) return;
    HapticFeedback.selectionClick();
    final PresenceCluster c = best.$2;
    _flyTo(
      -c.lng * math.pi / 180,
      c.lat * math.pi / 180,
      math.max(_scale, 1.9),
    );
  }

  /// Turns the globe so [lon]/[lat] face the viewer, at [scale].
  void _flyTo(double lon, double lat, double scale) {
    _spin.stop();
    // Turn the short way round.
    double target = lon;
    while (target - _lon > math.pi) {
      target -= 2 * math.pi;
    }
    while (target - _lon < -math.pi) {
      target += 2 * math.pi;
    }
    final CurvedAnimation curve = CurvedAnimation(
      parent: _fly,
      curve: Curves.easeInOutCubic,
    );
    _flyLon = Tween<double>(begin: _lon, end: target).animate(curve);
    _flyLat = Tween<double>(
      begin: _lat,
      end: lat.clamp(-_maxLat, _maxLat),
    ).animate(curve);
    _flyScale = Tween<double>(begin: _scale, end: scale).animate(curve);
    _fly.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    for (final PresenceCluster c in widget.clusters) {
      _born.putIfAbsent(c.geohash, () => now);
    }
    _born.removeWhere(
      (String k, _) =>
          !widget.clusters.any((PresenceCluster c) => c.geohash == k),
    );
    final ({ui.Image? day, ui.Image? night}) tex = NoorGlobe.textures;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final Size size = Size(box.maxWidth, box.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onStart,
          onScaleUpdate: (ScaleUpdateDetails d) => _onUpdate(d, size),
          onScaleEnd: _onEnd,
          onDoubleTap: _onDoubleTap,
          onTapUp: _onTapUp,
          child: AnimatedBuilder(
            animation: _breath,
            builder: (BuildContext context, _) => CustomPaint(
              size: size,
              painter: _TahajjudGlobePainter(
                day: tex.day,
                night: tex.night,
                lon: _lon,
                lat: _lat,
                scale: _scale,
                clusters: widget.clusters,
                born: _born,
                now: now,
                breath: Curves.easeInOut.transform(_breath.value),
                hits: _hits,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TahajjudGlobePainter extends CustomPainter {
  _TahajjudGlobePainter({
    required this.day,
    required this.night,
    required this.lon,
    required this.lat,
    required this.scale,
    required this.clusters,
    required this.born,
    required this.now,
    required this.breath,
    required this.hits,
  });

  final ui.Image? day;
  final ui.Image? night;
  final double lon;
  final double lat;
  final double scale;
  final List<PresenceCluster> clusters;
  final Map<String, DateTime> born;
  final DateTime now;
  final double breath;

  /// Filled during paint with where each light landed, for tapping.
  final List<(Offset, PresenceCluster)> hits;

  /// The sun, low and to the side: enough light to read the continents,
  /// while the greater part of the visible Earth is night, as it is at
  /// Tahajjud. The city lights do the rest.
  static const double _sunX = -0.72;
  static const double _sunY = 0.18;
  static const double _sunZ = 0.67;

  /// The stars, fixed: real stars do not move, the Earth does.
  static final List<(double, double, double, double)> _stars = () {
    final math.Random r = math.Random(14480);
    return List<(double, double, double, double)>.generate(
      170,
      (_) => (
        r.nextDouble(),
        r.nextDouble(),
        0.4 + r.nextDouble() * 1.1,
        r.nextDouble(),
      ),
    );
  }();

  /// Rotates a point on the unit sphere into view space: longitude about
  /// the poles, then latitude toward the viewer. Returns view x, y, z.
  (double, double, double) _view(double phi, double theta) {
    final double cosPhi = math.cos(phi);
    final double px = cosPhi * math.sin(theta + lon);
    final double py = math.sin(phi);
    final double pz = cosPhi * math.cos(theta + lon);
    final double cl = math.cos(lat);
    final double sl = math.sin(lat);
    // Tilt: bring the chosen latitude to the middle of the disc.
    final double y = py * cl - pz * sl;
    final double z = py * sl + pz * cl;
    return (px, y, z);
  }

  @override
  void paint(Canvas canvas, Size size) {
    hits.clear();
    final double radius = math.min(size.width, size.height) * 0.42 * scale;
    final Offset centre = Offset(size.width / 2, size.height * 0.47);

    _starfield(canvas, size, centre, radius);
    _atmosphere(canvas, centre, radius);

    final ui.Image? texture = day;
    if (texture == null) {
      canvas.drawCircle(centre, radius, Paint()..color = AppColors.navy);
    } else {
      _sphere(canvas, centre, radius, texture, night);
    }
    _lights(canvas, centre, radius);
    _rim(canvas, centre, radius);
  }

  void _starfield(Canvas canvas, Size size, Offset centre, double radius) {
    final Paint p = Paint();
    for (final (double x, double y, double r, double phase) in _stars) {
      final Offset at = Offset(x * size.width, y * size.height);
      if ((at - centre).distance < radius * 0.98) continue;
      // Most are steady; a few breathe, out of step with each other.
      final double tw = phase > 0.8
          ? 0.55 + 0.45 * math.sin((breath + phase) * math.pi)
          : 1;
      p.color = AppColors.cream.withValues(alpha: (0.25 + r * 0.35) * tw);
      canvas.drawCircle(at, r, p);
    }
  }

  void _atmosphere(Canvas canvas, Offset centre, double radius) {
    final double reach = radius * 1.22;
    canvas.drawCircle(
      centre,
      reach,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.transparent,
            const Color(0xFF2B5AA0).withValues(alpha: 0.04),
            const Color(0xFF2B5AA0).withValues(alpha: 0.16),
            const Color(0xFF4DA6FF).withValues(alpha: 0.26),
            const Color(0xFF2B5AA0).withValues(alpha: 0.10),
            Colors.transparent,
          ],
          stops: const <double>[0.55, 0.70, 0.79, 0.82, 0.90, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: reach))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.02),
    );
  }

  void _sphere(
    Canvas canvas,
    Offset centre,
    double radius,
    ui.Image texture,
    ui.Image? lights,
  ) {
    // Finer when closer, so the horizon stays a curve and not a polygon.
    final int cols = (80 * scale).round().clamp(80, 200);
    final int rows = cols ~/ 2;

    final Float32List positions = Float32List(cols * rows * 12);
    final Float32List texCoords = Float32List(cols * rows * 12);
    final Int32List dayColours = Int32List(cols * rows * 6);
    final Int32List nightColours = Int32List(cols * rows * 6);
    int v = 0;
    int c = 0;
    final double tw = texture.width.toDouble();
    final double th = texture.height.toDouble();

    (Offset, double, double, double)? corner(int row, int col) {
      final double u = col / cols;
      final double vv = row / rows;
      final double theta = (u - 0.5) * 2 * math.pi;
      final double phi = (0.5 - vv) * math.pi;
      final (double x, double y, double z) = _view(phi, theta);
      if (z < 0) return null;
      final double lit = (x * _sunX + y * _sunY + z * _sunZ).clamp(0.0, 1.0);
      return (centre + Offset(x * radius, -y * radius), u * tw, vv * th, lit);
    }

    void push((Offset, double, double, double) p) {
      positions[v] = p.$1.dx;
      texCoords[v] = p.$2;
      v++;
      positions[v] = p.$1.dy;
      texCoords[v] = p.$3;
      v++;
      final double lit = math.pow(p.$4, 0.6).toDouble();
      // Night-blue on the dark side, not black: a black Earth reads as a
      // hole in the sky.
      final double bright = (0.16 + lit * 0.62).clamp(0.0, 1.0);
      final int r = (bright * 205).round();
      final int g = (bright * 220).round();
      final int b = (bright * 255).round();
      dayColours[c] = (0xFF << 24) | (r << 16) | (g << 8) | b;
      final int lv = ((1 - lit) * 255).round().clamp(0, 255);
      nightColours[c] = (0xFF << 24) | (lv << 16) | (lv << 8) | lv;
      c++;
    }

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
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

    canvas.save();
    canvas.clipPath(
      ui.Path()..addOval(Rect.fromCircle(center: centre, radius: radius)),
    );
    canvas.drawVertices(
      ui.Vertices.raw(
        ui.VertexMode.triangles,
        Float32List.sublistView(positions, 0, v),
        textureCoordinates: Float32List.sublistView(texCoords, 0, v),
        colors: Int32List.sublistView(dayColours, 0, c),
      ),
      BlendMode.modulate,
      Paint()
        ..shader = ui.ImageShader(
          texture,
          TileMode.clamp,
          TileMode.clamp,
          Matrix4.identity().storage,
        )
        ..filterQuality = FilterQuality.high,
    );
    if (lights != null) {
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
          ..colorFilter = const ColorFilter.matrix(<double>[
            2.60, 0, 0, 0, -13.0, //
            2.10, 0, 0, 0, -10.5, //
            1.35, 0, 0, 0, -6.75, //
            0, 0, 0, 1, 0, //
          ])
          ..filterQuality = FilterQuality.high,
      );
    }
    canvas.restore();
  }

  /// The people praying: a glow each, on the surface, fading toward the
  /// limb, blooming in when they arrive.
  void _lights(Canvas canvas, Offset centre, double radius) {
    for (final PresenceCluster p in clusters) {
      final (double x, double y, double z) = _view(
        p.lat * math.pi / 180,
        p.lng * math.pi / 180,
      );
      if (z < 0.02) continue;
      final Offset at = centre + Offset(x * radius, -y * radius);
      final double age =
          now.difference(born[p.geohash] ?? now).inMilliseconds / 900.0;
      final double bloom = Curves.easeOutBack.transform(age.clamp(0.0, 1.0));
      final double limb = math.pow(z, 0.5).toDouble();
      // Small. A hundred people praying in one city must read as a scatter
      // of lights over it, not a blot — and your own light must never hide
      // the people around you. The size grows with the crowd only as its
      // logarithm, and yours is marked by a white point, not by being bigger.
      final double size =
          (2.6 + math.log(p.count + 1) * 1.3) *
          math.sqrt(scale) *
          bloom *
          (1 + breath * 0.12);
      final Color core = p.includesMe ? AppColors.pulseSoft : AppColors.pulse;

      canvas.drawCircle(
        at,
        size * 2.4,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              core.withValues(alpha: 0.95 * limb),
              AppColors.pulse.withValues(alpha: 0.4 * limb),
              AppColors.pulse.withValues(alpha: 0),
            ],
            stops: const <double>[0, 0.32, 1],
          ).createShader(Rect.fromCircle(center: at, radius: size * 2.4)),
      );
      // The ring that goes out, once, as the light arrives.
      if (age < 1.6) {
        final double ring = (age / 1.6).clamp(0.0, 1.0);
        canvas.drawCircle(
          at,
          size * (1.5 + ring * 4),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8
            ..color = AppColors.pulseSoft.withValues(
              alpha: (1 - ring) * 0.55 * limb,
            ),
        );
      }
      if (p.includesMe) {
        canvas.drawCircle(
          at,
          size * 0.55,
          Paint()..color = Colors.white.withValues(alpha: 0.95 * limb),
        );
      }
      hits.add((at, p));
    }
  }

  void _rim(Canvas canvas, Offset centre, double radius) {
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      math.pi * 1.05,
      math.pi * 0.9,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: <Color>[
            AppColors.pulseSoft.withValues(alpha: 0),
            AppColors.pulseSoft.withValues(alpha: 0.75),
            AppColors.pulseSoft.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: radius))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
  }

  @override
  bool shouldRepaint(_TahajjudGlobePainter old) => true;
}
