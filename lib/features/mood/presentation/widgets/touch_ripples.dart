import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/theme/app_colors.dart';

/// Rings that bloom from wherever a finger rests, and fade when it lifts.
///
/// Hold still and the rings stack into a target; drag and they trail the
/// finger across the screen. Nothing is recorded and nothing changes —
/// it exists because touching the screen on this section should feel like
/// touching water, not glass. Used on the mood screens only.
class TouchRipples extends StatefulWidget {
  const TouchRipples({super.key, required this.child, this.color});

  final Widget child;

  /// Defaults to gold. The deck screen passes the mood's own tone.
  final Color? color;

  @override
  State<TouchRipples> createState() => _TouchRipplesState();
}

class _Ripple {
  _Ripple(this.origin, this.born);
  final Offset origin;
  final Duration born;
}

class _TouchRipplesState extends State<TouchRipples>
    with SingleTickerProviderStateMixin {
  /// How long one ring takes to grow and vanish.
  static const Duration _life = Duration(milliseconds: 1500);

  /// A new ring while the finger is down, this often. Fast enough that a
  /// held finger builds a stack of concentric rings; slow enough that a
  /// drag leaves a trail rather than a solid stripe.
  static const Duration _every = Duration(milliseconds: 110);

  late final Ticker _ticker = createTicker(_tick);
  final List<_Ripple> _ripples = <_Ripple>[];
  Offset? _finger;

  /// One clock for the whole life of the widget.
  ///
  /// Rings used to be stamped with the ticker's elapsed time, and a ticker
  /// restarts from zero every time it is stopped and started. A quick tap
  /// after the last ring had faded stamped the new ring with a stale time
  /// from the previous run, the ticker restarted at zero, and the ring's age
  /// came out negative — clamped to nothing, it sat at its smallest size and
  /// half opacity for good. A stopwatch that is never stopped cannot do that.
  final Stopwatch _clock = Stopwatch()..start();
  Duration _now = Duration.zero;
  Duration _lastSpawn = Duration.zero;

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _down(PointerEvent e) {
    _now = _clock.elapsed;
    _finger = e.localPosition;
    _spawn(force: true);
    if (!_ticker.isActive) _ticker.start();
  }

  void _move(PointerEvent e) {
    _now = _clock.elapsed;
    _finger = e.localPosition;
    _spawn();
  }

  void _up(PointerEvent e) => _finger = null;

  void _spawn({bool force = false}) {
    final Offset? at = _finger;
    if (at == null) return;
    if (!force && _now - _lastSpawn < _every) return;
    _lastSpawn = _now;
    _ripples.add(_Ripple(at, _now));
  }

  void _tick(Duration _) {
    _now = _clock.elapsed;
    _spawn();
    _ripples.removeWhere((_Ripple r) => _now - r.born > _life);
    if (_ripples.isEmpty && _finger == null) {
      _ticker.stop();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Translucent, so buttons underneath still receive the tap; this layer
      // only listens, it never claims the gesture.
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RipplePainter(
                  ripples: _ripples,
                  now: _now,
                  life: _life,
                  color: widget.color ?? AppColors.gold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.ripples,
    required this.now,
    required this.life,
    required this.color,
  });

  final List<_Ripple> ripples;
  final Duration now;
  final Duration life;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    // A hazy twin of the ring, wider and blurred, so the edge glows rather
    // than cuts.
    final Paint halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final Paint glow = Paint();
    for (final _Ripple r in ripples) {
      final double t = ((now - r.born).inMicroseconds / life.inMicroseconds)
          .clamp(0, 1);
      // Grows fast then eases out, so the newest rings are the tightest and
      // the stack reads as expanding outward from the finger.
      final double grown = Curves.easeOutCubic.transform(t);
      final double radius = 10 + grown * 190;
      final double alpha = (1 - t) * 0.5;

      // Light pooled inside the ring: brightest at the centre, gone by the
      // rim, so a stack of rings reads as one soft glow with rings drawn
      // through it, the way the reference lays its circles over a haze.
      glow.shader = RadialGradient(
        colors: <Color>[
          color.withValues(alpha: alpha * 0.55),
          color.withValues(alpha: alpha * 0.18),
          color.withValues(alpha: 0),
        ],
        stops: const <double>[0, 0.55, 1],
      ).createShader(Rect.fromCircle(center: r.origin, radius: radius));
      canvas.drawCircle(r.origin, radius, glow);

      halo.color = color.withValues(alpha: alpha * 0.45);
      canvas.drawCircle(r.origin, radius, halo);

      ring.color = color.withValues(alpha: alpha);
      canvas.drawCircle(r.origin, radius, ring);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => true;
}
