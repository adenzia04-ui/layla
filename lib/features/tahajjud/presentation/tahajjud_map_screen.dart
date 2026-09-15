import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/state_views.dart';
import '../application/tahajjud_controller.dart';
import '../domain/tahajjud_presence.dart';
import 'widgets/tahajjud_globe.dart';

/// The live map. Every marker is a **geohash cell**, not a person — see
/// `core/utils/geohash.dart` for why, and `map_consent_sheet.dart` for what
/// the user was told before joining.
class TahajjudMapScreen extends ConsumerStatefulWidget {
  const TahajjudMapScreen({super.key});

  @override
  ConsumerState<TahajjudMapScreen> createState() => _TahajjudMapScreenState();
}

/// The two ways of looking: the globe, and the map it hands over to.
enum _Mode { globe, map }

/// Zoom bounds, shared by the map and the buttons that drive it.
const double _minZoom = 1.6;
const double _maxZoom = 18;

class _TahajjudMapScreenState extends ConsumerState<TahajjudMapScreen>
    with SingleTickerProviderStateMixin {
  final MapController _map = MapController();

  /// The globe first. Pinch past its detail and the map takes over at the
  /// same spot; pinch out on the map and the globe comes back.
  _Mode _mode = _Mode.globe;
  LatLng _focus = const LatLng(21.4225, 39.8262);

  /// Where the map picks up from the globe, and hands back to it.
  static const double _handoffZoom = 4.4;
  static const double _returnZoom = 3.4;

  void _toMap(LatLng centre) {
    if (_mode == _Mode.map) return;
    setState(() {
      _focus = centre;
      _mode = _Mode.map;
    });
  }

  void _toGlobe() {
    if (_mode == _Mode.globe) return;
    setState(() => _mode = _Mode.globe);
  }

  void _onMapEvent(MapEvent event) {
    if (_mode != _Mode.map) return;
    if (event is MapEventMoveEnd ||
        event is MapEventFlingAnimationEnd ||
        event is MapEventDoubleTapZoomEnd) {
      _focus = _map.camera.center;
      if (_map.camera.zoom < _returnZoom) _toGlobe();
    }
  }

  /// Drives every camera change the user did not make with their fingers.
  ///
  /// `MapController.move` is a teleport — it sets the camera and returns, with
  /// no motion at all. Centring on yourself or tapping a marker therefore cut
  /// straight to the destination, which is disorienting: the eye has no way to
  /// carry where it was to where it ended up. This tweens the centre and the
  /// zoom together and calls `move` on every tick, which is the only way to
  /// animate a flutter_map camera without pulling in another package.
  late final AnimationController _fly = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  Animation<double>? _lat;
  Animation<double>? _lng;
  Animation<double>? _zoom;

  /// Glows whose person has just left the map, kept for a moment so they
  /// can fade rather than blink out. A light that vanishes between one
  /// frame and the next reads as a glitch; one that dims reads as someone
  /// finishing their prayer.
  final Map<String, PresenceCluster> _lingering = <String, PresenceCluster>{};
  final Map<String, Timer> _lingerTimers = <String, Timer>{};
  List<PresenceCluster> _last = const <PresenceCluster>[];

  void _noteVanished(List<PresenceCluster> now) {
    final Set<String> present = now
        .map((PresenceCluster c) => c.geohash)
        .toSet();
    for (final PresenceCluster gone in _last) {
      if (present.contains(gone.geohash)) continue;
      _lingering[gone.geohash] = gone;
      _lingerTimers[gone.geohash]?.cancel();
      _lingerTimers[gone.geohash] = Timer(
        const Duration(milliseconds: 1800),
        () {
          if (!mounted) return;
          setState(() {
            _lingering.remove(gone.geohash);
            _lingerTimers.remove(gone.geohash);
          });
        },
      );
    }
    // Someone who came back is no longer leaving.
    for (final String key in present) {
      _lingerTimers.remove(key)?.cancel();
      _lingering.remove(key);
    }
    _last = now;
  }

  @override
  void initState() {
    super.initState();
    _fly.addListener(() {
      final Animation<double>? lat = _lat;
      final Animation<double>? lng = _lng;
      final Animation<double>? zoom = _zoom;
      if (lat == null || lng == null || zoom == null) return;
      _map.move(LatLng(lat.value, lng.value), zoom.value);
    });
  }

  @override
  void dispose() {
    for (final Timer t in _lingerTimers.values) {
      t.cancel();
    }
    _fly.dispose();
    _map.dispose();
    super.dispose();
  }

  /// Eases the camera to [dest] at [zoom].
  ///
  /// easeInOutCubic rather than a linear ramp: a camera that starts and stops
  /// at full speed reads as a cut, and the whole point is that the eye should
  /// be able to follow.
  void _flyTo(LatLng dest, double zoom, {Duration? over}) {
    final MapCamera now = _map.camera;
    final CurvedAnimation curve = CurvedAnimation(
      parent: _fly,
      curve: Curves.easeInOutCubic,
    );
    _lat = Tween<double>(
      begin: now.center.latitude,
      end: dest.latitude,
    ).animate(curve);
    _lng = Tween<double>(
      begin: now.center.longitude,
      end: dest.longitude,
    ).animate(curve);
    _zoom = Tween<double>(
      begin: now.zoom,
      end: zoom.clamp(_minZoom, _maxZoom),
    ).animate(curve);

    _fly
      ..duration = over ?? const Duration(milliseconds: 650)
      ..forward(from: 0);
  }

  /// One step of zoom, about the point already at the centre.
  ///
  /// Shorter than a fly-to, because nothing is travelling — only the scale
  /// changes, and 650ms of that feels sluggish rather than smooth.
  void _zoomBy(double delta) => _flyTo(
    _map.camera.center,
    _map.camera.zoom + delta,
    over: const Duration(milliseconds: 320),
  );

  void _centreOnMe(List<PresenceCluster> clusters) {
    for (final PresenceCluster cluster in clusters) {
      if (cluster.includesMe) {
        _flyTo(LatLng(cluster.lat, cluster.lng), 11);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PresenceCluster>> clusters = ref.watch(
      presenceClustersProvider,
    );
    ref.listen(presenceClustersProvider, (
      AsyncValue<List<PresenceCluster>>? prev,
      AsyncValue<List<PresenceCluster>> next,
    ) {
      final List<PresenceCluster>? now = next.valueOrNull;
      if (now != null) setState(() => _noteVanished(now));
    });
    final int total = ref.watch(tahajjudLiveCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: Stack(
        // Expand, or the stack sizes itself to the header: in globe mode
        // nothing else is unpositioned, and the globe got a box the height
        // of one line of text.
        fit: StackFit.expand,
        children: <Widget>[
          if (_mode == _Mode.globe)
            Positioned.fill(
              child: TahajjudGlobe(
                clusters: clusters.valueOrNull ?? const <PresenceCluster>[],
                initialFocus: _focus,
                onFocus: (LatLng c) => _focus = c,
                onDetail: _toMap,
              ),
            ),
          if (_mode == _Mode.map)
            clusters.when(
              loading: () => const LoadingView(message: 'Finding believers…'),
              error: (Object error, StackTrace stack) => ErrorView(
                message: 'The live map could not load.',
                onRetry: () => ref.invalidate(tahajjudPresenceProvider),
              ),
              data: (List<PresenceCluster> list) => FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: _focus,
                  initialZoom: _handoffZoom,
                  onMapEvent: _onMapEvent,
                  // Night, not the package's default light grey.
                  //
                  // Web Mercator stops at about 85 degrees, and at [_minZoom] the
                  // whole world is shorter than a phone screen — so there is
                  // always sky above and below the map, and it was being painted
                  // #E0E0E0. A grey slab above a night map is the first thing the
                  // eye goes to, and it is also what shows for the moment before
                  // tiles arrive.
                  //
                  // Constraining the camera instead was the other option and is
                  // the wrong one: the world genuinely does not fill the viewport
                  // at this zoom, so containing it would force a zoom-in and take
                  // away seeing the whole earth at once, which is the point of
                  // the screen.
                  backgroundColor: AppColors.midnight,
                  minZoom: _minZoom,
                  // Zoom all the way in.
                  //
                  // The data behind it is a precision-5 geohash — a 4.9 km cell,
                  // and the only spatial value that ever leaves a phone. Rather
                  // than cap the zoom to hide that, the cell is now drawn at its
                  // true size (see the CircleLayer below), so going closer shows
                  // a 4.9 km circle rather than a pin pretending to be a street
                  // address. Honest at every zoom, instead of restricted.
                  maxZoom: _maxZoom,
                  interactionOptions: const InteractionOptions(
                    // pinchMove matters as much as pinchZoom: without it the
                    // map is pinned while two fingers are down, so a pinch that
                    // drifts even slightly fights the hand instead of following
                    // it. That fighting is most of what reads as "not smooth".
                    flags:
                        InteractiveFlag.drag |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.pinchMove |
                        InteractiveFlag.doubleTapZoom |
                        InteractiveFlag.flingAnimation,
                  ),
                ),
                children: <Widget>[
                  // Real imagery: sea, coastline, forest and desert as they
                  // actually are, rather than the flat monochrome basemap this
                  // used to draw. Esri's world imagery needs no key.
                  TileLayer(
                    urlTemplate:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/'
                        'World_Imagery/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'com.noorapp.noor',
                    maxNativeZoom: 18,
                    retinaMode: RetinaMode.isHighDensity(context),
                  ),

                  // A wash of navy over the imagery.
                  //
                  // Satellite tiles are daylight photographs, and a sunlit earth
                  // under a screen called Tahajjud is the wrong thing entirely.
                  // This is not decoration: it puts the map back at night and
                  // lets the gold markers read against it, which they cannot do
                  // over bright terrain.
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            AppColors.midnight.withValues(alpha: 0.62),
                            AppColors.navy.withValues(alpha: 0.52),
                          ],
                        ),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                  // Place names. Satellite imagery carries none at all — no
                  // cities, no countries, no borders — so they come from Esri's
                  // transparent reference layer, drawn over the night wash so
                  // they stay legible rather than being dimmed with the map.
                  TileLayer(
                    urlTemplate:
                        'https://server.arcgisonline.com/ArcGIS/rest/services/'
                        'Reference/World_Boundaries_and_Places/MapServer/'
                        'tile/{z}/{y}/{x}',
                    userAgentPackageName: 'com.noorapp.noor',
                    maxNativeZoom: 18,
                    retinaMode: RetinaMode.isHighDensity(context),
                  ),

                  // The cell each marker actually stands for.
                  //
                  // Radius in metres, not pixels: at world zoom it is a dot
                  // under the marker, and up close it grows into the real 4.9 km
                  // square-ish area the geohash describes. That is the whole
                  // point — someone zooming in sees the uncertainty rather than
                  // a false precision.
                  CircleLayer(
                    circles: <CircleMarker>[
                      for (final PresenceCluster c in list)
                        CircleMarker(
                          point: LatLng(c.lat, c.lng),
                          radius: 2450, // half of the 4.9 km cell
                          useRadiusInMeter: true,
                          // No border. A drawn ring reads as a boundary — a
                          // fence around somebody — when all it means is "about
                          // here". A borderless wash says the same thing without
                          // ever drawing an edge that isn't real.
                          color: AppColors.pulse.withValues(alpha: 0.07),
                          borderStrokeWidth: 0,
                        ),
                    ],
                  ),

                  MarkerLayer(
                    markers: <Marker>[
                      for (final PresenceCluster c in list)
                        Marker(
                          point: LatLng(c.lat, c.lng),
                          width: 72,
                          height: 72,
                          child: _ClusterMarker(
                            key: ValueKey<String>(c.geohash),
                            cluster: c,
                          ),
                        ),
                      for (final PresenceCluster c in _lingering.values)
                        Marker(
                          point: LatLng(c.lat, c.lng),
                          width: 72,
                          height: 72,
                          child: _ClusterMarker(
                            key: ValueKey<String>('gone-${c.geohash}'),
                            cluster: c,
                            vanishing: true,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          // The night itself, alive: a scatter of stars over the map that
          // brighten and dim on their own time, so a map with nobody on it
          // is still a sky and not a blank.
          if (_mode == _Mode.map)
            const Positioned.fill(child: IgnorePointer(child: _NightLife())),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _MapHeader(total: total),
          ),
          Positioned(
            left: Insets.lg,
            right: Insets.lg,
            bottom: Insets.lg,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  // Zoom, for anyone who would rather tap than pinch — and
                  // because a pinch cannot be done one-handed on a phone this
                  // size. Both eased, so tapping repeatedly glides rather than
                  // stepping.
                  if (_mode == _Mode.map)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.md),
                      child: _ZoomButton(
                        icon: Icons.public_rounded,
                        tooltip: 'Back to the globe',
                        onTap: _toGlobe,
                      ),
                    ),
                  if (_mode == _Mode.globe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.md),
                      child: _ZoomButton(
                        icon: Icons.zoom_in_map_rounded,
                        tooltip: 'Closer — the map',
                        onTap: () => _toMap(_focus),
                      ),
                    ),
                  if (_mode == _Mode.map)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.md),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _ZoomButton(
                            icon: Icons.add_rounded,
                            tooltip: 'Zoom in',
                            onTap: () => _zoomBy(1),
                          ),
                          const SizedBox(height: 1),
                          _ZoomButton(
                            icon: Icons.remove_rounded,
                            tooltip: 'Zoom out',
                            onTap: () => _zoomBy(-1),
                          ),
                        ],
                      ),
                    ),
                  if (_mode == _Mode.map &&
                      clusters.hasValue &&
                      clusters.requireValue.any(
                        (PresenceCluster c) => c.includesMe,
                      ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.md),
                      child: FloatingActionButton.small(
                        heroTag: 'centre-me',
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.midnight,
                        onPressed: () => _centreOnMe(clusters.requireValue),
                        child: const Icon(Icons.my_location_rounded),
                      ),
                    ),
                  const _PrivacyFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Row(
          children: <Widget>[
            CircleIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onPressed: () => context.pop(),
              background: AppColors.navy.withValues(alpha: 0.9),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                  vertical: Insets.md,
                ),
                decoration: BoxDecoration(
                  color: AppColors.navy.withValues(alpha: 0.92),
                  borderRadius: Radii.chip,
                  border: Border.all(color: AppColors.navyLine),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      height: 8,
                      width: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.emerald,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    Expanded(
                      child: Text(
                        total == 0
                            ? 'Nobody is praying right now'
                            : total == 1
                            ? '1 believer praying Tahajjud'
                            : '$total believers praying Tahajjud',
                        style: AppType.titleSm.copyWith(color: AppColors.cream),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One half of the zoom pair.
///
/// Deliberately not a FloatingActionButton: two stacked FABs on a dark map is
/// a lot of gold competing with the glows, and the pair reads better as one
/// small slab split in two.
class _ZoomButton extends StatelessWidget {
  const _ZoomButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: AppColors.navy.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 38,
          width: 38,
          child: Icon(icon, size: 20, color: AppColors.cream),
        ),
      ),
    ),
  );
}

/// A person praying, at this moment, about here.
///
/// It breathes: a soft halo swelling and settling around a bright core. It
/// blooms when it first appears — a ring spreading out from nothing, the way
/// a lamp is lit — and every few seconds another faint ring goes out from
/// it, so a map with three people on it moves the way a night sky does.
/// When the person leaves, it dims out over a couple of seconds instead of
/// blinking away.
class _ClusterMarker extends StatefulWidget {
  const _ClusterMarker({
    super.key,
    required this.cluster,
    this.vanishing = false,
  });

  final PresenceCluster cluster;
  final bool vanishing;

  @override
  State<_ClusterMarker> createState() => _ClusterMarkerState();
}

class _ClusterMarkerState extends State<_ClusterMarker>
    with TickerProviderStateMixin {
  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  /// The lighting of the lamp: runs once, forward, when the glow appears.
  late final AnimationController _bloom = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  /// The rings that go out from it, one every few seconds. Started at a
  /// random phase so a city of lights does not pulse in lock-step.
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
    value: math.Random(widget.cluster.geohash.hashCode).nextDouble(),
  )..repeat();

  @override
  void dispose() {
    _beat.dispose();
    _bloom.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool mine = widget.cluster.includesMe;
    final int count = widget.cluster.count;
    // Grows with the crowd, but slowly — a hundred people must still be a
    // glow and not a blot across a country.
    final double size = 34 + count.clamp(0, 40) * 0.5;

    final Widget glow = AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_beat, _bloom, _ring]),
      builder: (BuildContext context, _) {
        final double t = Curves.easeInOut.transform(_beat.value);
        final double lit = Curves.easeOutBack.transform(_bloom.value);
        final double ring = _ring.value;
        return SizedBox(
          height: 72,
          width: 72,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // The ring going out: born at the core, gone by the edge.
              Container(
                height: 14 + ring * 58,
                width: 14 + ring * 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.pulse.withValues(alpha: (1 - ring) * 0.45),
                    width: 1,
                  ),
                ),
              ),
              // The first ring, once, as the lamp is lit.
              if (_bloom.isAnimating)
                Container(
                  height: 10 + _bloom.value * 62,
                  width: 10 + _bloom.value * 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.pulseSoft.withValues(
                        alpha: (1 - _bloom.value) * 0.7,
                      ),
                      width: 1.2,
                    ),
                  ),
                ),
              // A radial falloff, not a disc with a shadow: brightest at the
              // middle and gone by the rim, which is what a 5 km guess
              // actually looks like.
              Transform.scale(
                scale: lit * (1 + t * 0.18),
                child: Container(
                  height: size,
                  width: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        (mine ? AppColors.pulseSoft : AppColors.pulse)
                            .withValues(alpha: 0.95),
                        AppColors.pulse.withValues(alpha: 0.55),
                        AppColors.pulse.withValues(alpha: 0.18),
                        AppColors.pulse.withValues(alpha: 0),
                      ],
                      stops: const <double>[0.0, 0.28, 0.58, 1.0],
                    ),
                  ),
                ),
              ),
              // Yours burns a little hotter rather than wearing a ring.
              if (mine)
                Container(
                  height: size * 0.34,
                  width: size * 0.34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        Colors.white.withValues(alpha: 0.85),
                        AppColors.pulseSoft.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              // The count only when it says something.
              if (count > 1)
                Text(
                  '$count',
                  style: AppType.numeral.copyWith(
                    fontSize: 11,
                    color: AppColors.cream,
                    shadows: const <Shadow>[
                      Shadow(color: Color(0xCC060D1B), blurRadius: 4),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (!widget.vanishing) return Center(child: glow);

    // Leaving: dim and settle over the time the map keeps it.
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1, end: 0),
        duration: const Duration(milliseconds: 1600),
        curve: Curves.easeInCubic,
        builder: (BuildContext context, double v, Widget? child) => Opacity(
          opacity: v,
          child: Transform.scale(scale: 0.7 + v * 0.3, child: child),
        ),
        child: glow,
      ),
    );
  }
}

/// Stars over the map, each on its own slow time.
///
/// Fixed places, seeded so they are the same every time the screen opens,
/// and a period long enough that nothing flickers: the sky should be seen
/// to be alive only if you watch it.
class _NightLife extends StatefulWidget {
  const _NightLife();

  @override
  State<_NightLife> createState() => _NightLifeState();
}

class _NightLifeState extends State<_NightLife>
    with SingleTickerProviderStateMixin {
  late final AnimationController _time = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();

  static final List<(double, double, double, double)> _stars = () {
    final math.Random r = math.Random(1948);
    return List<(double, double, double, double)>.generate(
      28,
      (_) => (
        r.nextDouble(),
        r.nextDouble(),
        r.nextDouble(),
        0.6 + r.nextDouble() * 1.1,
      ),
    );
  }();

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _time,
      builder: (BuildContext context, _) => CustomPaint(
        painter: _StarPainter(phase: _time.value, stars: _stars),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter({required this.phase, required this.stars});

  final double phase;
  final List<(double, double, double, double)> stars;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint();
    for (final (double x, double y, double offset, double r) in stars) {
      // Each star brightens and dims on a sine of its own phase; most sit
      // near invisible and a few at a time come up.
      final double a = 0.5 + 0.5 * math.sin((phase + offset) * 2 * math.pi);
      final double alpha = 0.08 + a * a * 0.5;
      final Offset c = Offset(x * size.width, y * size.height);
      p.color = AppColors.cream.withValues(alpha: alpha * 0.25);
      canvas.drawCircle(c, r * 2.6, p);
      p.color = AppColors.cream.withValues(alpha: alpha);
      canvas.drawCircle(c, r, p);
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.phase != phase;
}

class _PrivacyFooter extends StatelessWidget {
  const _PrivacyFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.navyLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.shield_outlined,
                size: 15,
                color: AppColors.goldDim,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Each glow is a ~5 km area, not a person. Exact locations '
                  'are never shared.',
                  style: AppType.bodySm.copyWith(
                    fontSize: 11,
                    color: AppColors.mistFaint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '© Esri, Maxar, Earthstar Geographics',
            style: AppType.bodySm.copyWith(
              fontSize: 9,
              color: AppColors.mistFaint.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
