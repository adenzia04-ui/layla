import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/ornament_backdrop.dart';
import '../../domain/mood_comfort.dart';

/// The verse as a story-sized image, in Layla Pro's own theme.
///
/// 9:16, drawn at 360×640 logical and captured at 3× for a 1080×1920 PNG —
/// the size Instagram and TikTok stories expect. The mark and the name sit
/// at the top so whoever sees the story knows where it came from; below
/// them the words, lit in the colour of the feeling they were found for,
/// inside a halo of rings and a faint mihrab, the way the app itself looks.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.comfort, required this.mood});

  final Comfort comfort;
  final Mood mood;

  static const Size size = Size(360, 640);

  @override
  Widget build(BuildContext context) {
    final bool quran = comfort.source == ComfortSource.quran;
    final Color tone = mood.tone;
    // Rendered off-screen in a bare overlay, so nothing above it supplies a
    // text style — and a Text with no style falls back to Flutter's alarm
    // look, yellow double underlines. The Material gives it a proper default.
    return Material(
      type: MaterialType.transparency,
      child: SizedBox.fromSize(
        size: size,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.nightSky),
          child: Stack(
            children: <Widget>[
              // The feeling's light, and the rings that ripple out of it.
              Positioned.fill(child: CustomPaint(painter: _HaloPainter(tone))),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: OrnamentBackdrop(height: 300, opacity: 0.22),
              ),
              // A hairline frame, set in from the edge: a card, not a poster.
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(40, 52, 40, 44),
                child: Column(
                  children: <Widget>[
                    Image.asset('assets/images/layla_mark.png', height: 62),
                    const SizedBox(height: 10),
                    Text(
                      'L A Y L A',
                      style: AppType.label.copyWith(
                        color: AppColors.gold,
                        letterSpacing: 5,
                      ),
                    ),
                    const Spacer(),
                    if (comfort.arabic != null) ...<Widget>[
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          comfort.arabic!,
                          textAlign: TextAlign.center,
                          style: AppType.quran(27).copyWith(
                            color: AppColors.goldSoft,
                            height: 1.9,
                            shadows: <Shadow>[
                              Shadow(
                                color: tone.withValues(alpha: 0.55),
                                blurRadius: 22,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _Divider(color: tone),
                      const SizedBox(height: 22),
                    ],
                    Text(
                      quran ? '“${comfort.english}”' : comfort.english,
                      textAlign: TextAlign.center,
                      style: AppType.body.copyWith(
                        color: AppColors.cream,
                        fontSize: 16.5,
                        height: 1.65,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: tone.withValues(alpha: 0.12),
                        border: Border.all(color: tone.withValues(alpha: 0.55)),
                      ),
                      child: Text(
                        comfort.reference,
                        style: AppType.titleSm.copyWith(color: tone),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(mood.icon, size: 14, color: tone),
                        const SizedBox(width: 6),
                        Text(
                          'for the ${mood.label.toLowerCase()} heart',
                          style: AppType.bodySm.copyWith(color: AppColors.mist),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Keep your prayers with you',
                      style: AppType.bodySm.copyWith(
                        color: AppColors.mistFaint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The light behind the words: a soft glow in the feeling's colour, high
/// on one side like a moon, rings spreading out of it, and a mihrab drawn
/// faintly through the middle so the words stand in an arch.
class _HaloPainter extends CustomPainter {
  const _HaloPainter(this.tone);

  final Color tone;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset moon = Offset(size.width * 0.84, size.height * 0.2);

    canvas.drawCircle(
      moon,
      220,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            tone.withValues(alpha: 0.34),
            tone.withValues(alpha: 0.10),
            tone.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: moon, radius: 220)),
    );

    // A second, fainter light low on the other side, so the card is lit from
    // two places and the middle stays dark enough for the words.
    final Offset ember = Offset(size.width * 0.1, size.height * 0.86);
    canvas.drawCircle(
      ember,
      180,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            AppColors.gold.withValues(alpha: 0.14),
            AppColors.gold.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: ember, radius: 180)),
    );

    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (int i = 0; i < 6; i++) {
      ring.color = AppColors.gold.withValues(alpha: 0.2 - i * 0.025);
      canvas.drawCircle(moon, 60 + i * 42, ring);
    }

    // The mihrab, centred, just visible.
    final double w = size.width * 0.62;
    final double h = size.height * 0.6;
    final Rect r = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.53),
      width: w,
      height: h,
    );
    final Path arch = Path()
      ..moveTo(r.left, r.bottom)
      ..lineTo(r.left, r.top + h * 0.34)
      ..cubicTo(
        r.left,
        r.top + h * 0.1,
        r.center.dx - w * 0.3,
        r.top,
        r.center.dx,
        r.top,
      )
      ..cubicTo(
        r.center.dx + w * 0.3,
        r.top,
        r.right,
        r.top + h * 0.1,
        r.right,
        r.top + h * 0.34,
      )
      ..lineTo(r.right, r.bottom)
      ..close();
    canvas.drawPath(
      arch,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            tone.withValues(alpha: 0.10),
            tone.withValues(alpha: 0.0),
          ],
        ).createShader(r),
    );
    canvas.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = AppColors.gold.withValues(alpha: 0.22),
    );

    // Four small stars at the corners of the frame.
    final Paint star = Paint()..color = AppColors.gold.withValues(alpha: 0.55);
    for (final Offset c in <Offset>[
      const Offset(30, 30),
      Offset(size.width - 30, 30),
      Offset(30, size.height - 30),
      Offset(size.width - 30, size.height - 30),
    ]) {
      canvas.drawPath(_fourPoint(c, 5), star);
    }
  }

  Path _fourPoint(Offset c, double r) {
    final Path p = Path();
    for (int i = 0; i < 8; i++) {
      final double a = i * math.pi / 4 - math.pi / 2;
      final double rr = i.isEven ? r : r * 0.38;
      final Offset pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    return p..close();
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.tone != tone;
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.5)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(Icons.star_rounded, size: 12, color: color),
        ),
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.5)),
        ),
      ],
    );
  }
}

/// Renders a [ShareCard] to PNG bytes.
///
/// The card is mounted for a moment in an overlay, two thousand points off
/// the left edge of the screen, because a widget can only be rasterised once
/// it has been laid out and painted — and `Offstage` and `Opacity(0)` both
/// skip painting. Two frames are waited so the mark and fonts have loaded.
Future<Uint8List> renderShareCard(
  BuildContext context, {
  required Comfort comfort,
  required Mood mood,
}) async {
  // The mark is decoded before the card is even built. Two frames were not
  // always enough for an asset image the first time it was used, and the
  // card went out with a blank where the logo should have been.
  await precacheImage(
    const AssetImage('assets/images/layla_mark.png'),
    context,
  );
  if (!context.mounted) return Uint8List(0);

  final GlobalKey key = GlobalKey();
  final OverlayEntry entry = OverlayEntry(
    builder: (BuildContext _) => Positioned(
      left: -2000,
      top: 0,
      child: RepaintBoundary(
        key: key,
        child: ShareCard(comfort: comfort, mood: mood),
      ),
    ),
  );
  Overlay.of(context, rootOverlay: true).insert(entry);
  try {
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final RenderRepaintBoundary boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3);
    final ByteData? bytes = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    return bytes!.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}
