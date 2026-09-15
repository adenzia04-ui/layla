import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/mihrab_arch.dart';

/// The compass face: a rotating gold dial, cardinal marks, and a Kaaba needle
/// that turns emerald the moment the phone is facing the Qibla.
class QiblaCompass extends StatefulWidget {
  const QiblaCompass({
    super.key,
    required this.heading,
    required this.qiblaBearing,
    required this.aligned,
    this.size = 300,
  });

  /// Device heading in degrees; null when there is no magnetometer.
  final double? heading;
  final double qiblaBearing;
  final bool aligned;
  final double size;

  @override
  State<QiblaCompass> createState() => _QiblaCompassState();
}

class _QiblaCompassState extends State<QiblaCompass> {
  /// Turns, accumulated rather than wrapped.
  ///
  /// `AnimatedRotation` animates between the numbers it is given, so feeding it
  /// `-heading / 360` sent the dial the long way round every time the phone
  /// crossed north: 359° to 0° is one degree of movement but a jump from
  /// -0.997 to 0, and the dial dutifully unwound a whole revolution. Keeping a
  /// running total and adding only the shortest signed step keeps the number
  /// continuous, so one degree of turning is one degree of animation.
  double _turns = 0;
  double? _lastHeading;

  @override
  void initState() {
    super.initState();
    _turns = ((widget.heading ?? 0) * -1) / 360;
    _lastHeading = widget.heading;
  }

  @override
  void didUpdateWidget(QiblaCompass old) {
    super.didUpdateWidget(old);
    final double? now = widget.heading;
    if (now == null) return;
    final double? was = _lastHeading;
    _lastHeading = now;
    if (was == null) {
      _turns = -now / 360;
      return;
    }
    // Shortest way round, signed: +179 goes forward, +181 goes back one degree.
    double delta = (now - was) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    _turns -= delta / 360;
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.size;
    final bool aligned = widget.aligned;
    final double dialTurns = _turns;
    final double needleTurns = widget.qiblaBearing / 360;

    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // outer glow when aligned
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            height: size,
            width: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: aligned
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppColors.emerald.withValues(alpha: 0.34),
                        blurRadius: 40,
                        spreadRadius: 6,
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
          ),
          // the dial turns opposite the phone, so north stays north
          AnimatedRotation(
            turns: dialTurns,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: CustomPaint(
              size: Size.square(size),
              painter: _DialPainter(aligned: aligned),
            ),
          ),
          // the needle sits at the Qibla bearing, inside the rotating dial
          AnimatedRotation(
            turns: dialTurns + needleTurns,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: SizedBox(
              height: size,
              width: size,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: size * 0.055),
                  child: _KaabaNeedle(aligned: aligned, size: size * 0.15),
                ),
              ),
            ),
          ),
          // fixed centre hub
          Container(
            height: size * 0.30,
            width: size * 0.30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.navy,
              border: Border.all(
                color: aligned ? AppColors.emerald : AppColors.goldDim,
                width: 1.4,
              ),
            ),
            alignment: Alignment.center,
            child: SizedBox(
              height: size * 0.16,
              width: size * 0.12,
              child: MihrabOutline(
                color: aligned ? AppColors.emerald : AppColors.gold,
                strokeWidth: 1.2,
                innerArch: false,
              ),
            ),
          ),
          // fixed pointer at the top of the screen — "you are facing this way"
          Positioned(
            top: 0,
            child: Icon(
              Icons.arrow_drop_down_rounded,
              size: 30,
              color: aligned ? AppColors.emerald : AppColors.cream,
            ),
          ),
        ],
      ),
    );
  }
}

class _KaabaNeedle extends StatelessWidget {
  const _KaabaNeedle({required this.aligned, required this.size});

  final bool aligned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color color = aligned ? AppColors.emerald : AppColors.gold;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // The arrow, pointing out of the dial along the bearing.
        //
        // The block alone marks *where* the Kaaba is; it does not say which
        // way. At a glance a small rectangle near the rim reads as a tick on
        // the scale, and the tail below it can be mistaken for the pointer,
        // which points inward — the wrong way. A triangle aimed outward is
        // unambiguous from across a room, which is the distance this is
        // actually read from when it is on the floor beside a mat.
        CustomPaint(
          size: Size(size * 0.82, size * 0.66),
          painter: _ArrowPainter(color),
        ),
        SizedBox(height: size * 0.06),
        // The Kaaba as it actually is: black, with the gold band of the
        // kiswah across it. It used to be the inverse — a gold block with a
        // dark stripe — which reads as a generic marker rather than the thing
        // being pointed at.
        Container(
          height: size * 0.62,
          width: size * 0.72,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.midnight,
            borderRadius: BorderRadius.circular(3),
            // A hairline, so the black still separates from the navy dial.
            border: Border.all(color: color.withValues(alpha: 0.55)),
            boxShadow: <BoxShadow>[
              BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10),
            ],
          ),
          // 20% black, then the band, then the rest black. Flex rather than
          // fixed heights so the proportions hold at every dial size.
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Spacer(flex: 20),
              Expanded(flex: 10, child: ColoredBox(color: color)),
              const Spacer(flex: 70),
            ],
          ),
        ),
      ],
    );
  }
}

/// The triangle above the Kaaba block, filled and pointing outward.
class _ArrowPainter extends CustomPainter {
  const _ArrowPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Path head = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas
      ..drawPath(
        head,
        Paint()
          ..color = color.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawPath(head, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color;
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.aligned});

  final bool aligned;

  static const List<String> _cardinals = <String>['N', 'E', 'S', 'W'];

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width / 2;

    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = (aligned ? AppColors.emerald : AppColors.goldDim).withValues(
          alpha: 0.9,
        ),
    );
    canvas.drawCircle(
      c,
      r * 0.80,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppColors.navyLine,
    );

    // 72 ticks: every 5°, longer every 30°
    for (int i = 0; i < 72; i++) {
      final double angle = i * 5 * math.pi / 180 - math.pi / 2;
      final bool major = i % 6 == 0;
      final double inner = r * (major ? 0.84 : 0.90);
      final double outer = r * 0.965;
      canvas.drawLine(
        c + Offset(math.cos(angle), math.sin(angle)) * inner,
        c + Offset(math.cos(angle), math.sin(angle)) * outer,
        Paint()
          ..strokeWidth = major ? 1.6 : 0.8
          ..strokeCap = StrokeCap.round
          ..color = major
              ? AppColors.cream.withValues(alpha: 0.55)
              : AppColors.cream.withValues(alpha: 0.18),
      );
    }

    for (int i = 0; i < 4; i++) {
      final double angle = i * 90 * math.pi / 180 - math.pi / 2;
      final Offset position =
          c + Offset(math.cos(angle), math.sin(angle)) * (r * 0.68);
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: _cardinals[i],
          style: AppType.titleSm.copyWith(
            color: i == 0 ? AppColors.gold : AppColors.mist,
            fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        position - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.aligned != aligned;
}
