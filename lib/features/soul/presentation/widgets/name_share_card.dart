import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/names_detail.dart';
import '../../domain/names_of_allah.dart';

/// A story-sized card for one of the Names: the calligraphy large in gold on
/// the night, the meaning beneath, and the dua that calls by it — the same
/// family as the Mood share cards.
class NameShareCard extends StatelessWidget {
  const NameShareCard({
    super.key,
    required this.name,
    required this.number,
    required this.detail,
  });

  final DivineName name;
  final int number;
  final NameDetail detail;

  static const Size size = Size(360, 640);

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppColors.nightSky),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const CustomPaint(painter: _NameHaloPainter()),
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Image.asset(
                      'assets/images/layla_mark.png',
                      height: 44,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(height: Insets.md),
                    Text(
                      '$number OF 99',
                      style: AppType.label.copyWith(color: AppColors.goldDim),
                    ),
                    const Spacer(),
                    Directionality(
                      textDirection: TextDirection.rtl,
                      child: Text(
                        name.arabic,
                        textAlign: TextAlign.center,
                        style: AppType.quran(72).copyWith(
                          color: AppColors.goldSoft,
                          height: 1.4,
                          shadows: <Shadow>[
                            Shadow(
                              color: AppColors.gold.withValues(alpha: 0.5),
                              blurRadius: 36,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    Text(
                      name.transliteration,
                      textAlign: TextAlign.center,
                      style: AppType.displayMd.copyWith(color: AppColors.cream),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      name.meaning,
                      textAlign: TextAlign.center,
                      style: AppType.body.copyWith(color: AppColors.gold),
                    ),
                    const Spacer(),
                    Container(
                      width: 48,
                      height: 1,
                      color: AppColors.gold.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: Insets.lg),
                    Text(
                      detail.dua,
                      textAlign: TextAlign.center,
                      style: AppType.body.copyWith(
                        color: AppColors.cream,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'LAYLA PRO',
                      style: AppType.label.copyWith(
                        color: AppColors.mistFaint,
                        letterSpacing: 3,
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

class _NameHaloPainter extends CustomPainter {
  const _NameHaloPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height * 0.42);
    canvas.drawCircle(
      centre,
      220,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            AppColors.gold.withValues(alpha: 0.22),
            AppColors.gold.withValues(alpha: 0.06),
            AppColors.gold.withValues(alpha: 0),
          ],
          stops: const <double>[0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: centre, radius: 220)),
    );
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      ring.color = AppColors.gold.withValues(alpha: 0.10 - i * 0.02);
      canvas.drawCircle(centre, 120 + i * 36.0, ring);
    }
    // The mihrab, faint, behind everything.
    final Rect arch = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.62),
      width: size.width * 0.78,
      height: size.height * 0.9,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        arch,
        topLeft: Radius.circular(arch.width / 2),
        topRight: Radius.circular(arch.width / 2),
      ),
      ring..color = AppColors.gold.withValues(alpha: 0.08),
    );
  }

  @override
  bool shouldRepaint(_NameHaloPainter oldDelegate) => false;
}

/// Draws the card off-screen at 3× and hands back the PNG.
Future<Uint8List> renderNameCard(
  BuildContext context, {
  required DivineName name,
  required int number,
  required NameDetail detail,
}) async {
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
        child: NameShareCard(name: name, number: number, detail: detail),
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
    return bytes!.buffer.asUint8List();
  } finally {
    entry.remove();
  }
}

/// Renders the card and opens the share sheet from [origin].
Future<void> shareName(
  BuildContext context, {
  required DivineName name,
  required int number,
  required NameDetail detail,
}) async {
  final Uint8List png = await renderNameCard(
    context,
    name: name,
    number: number,
    detail: detail,
  );
  if (png.isEmpty || !context.mounted) return;
  final Directory dir = await getTemporaryDirectory();
  final File file = File('${dir.path}/layla-name-$number.png');
  await file.writeAsBytes(png, flush: true);
  if (!context.mounted) return;
  final RenderBox? box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(file.path, mimeType: 'image/png')],
      sharePositionOrigin: box == null
          ? null
          : box.localToGlobal(Offset.zero) & box.size,
    ),
  );
}
