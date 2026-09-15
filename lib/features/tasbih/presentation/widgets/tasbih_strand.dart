import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show ByteData, rootBundle;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// A strand of beads that travels as you count.
///
/// The alternative to [TasbihRing] for people who count on a physical misbaha:
/// the number matters less than the feel of a bead passing under the thumb.
///
/// Beads ride a shallow curve laid out with `PathMetric`, so reshaping the
/// curve redistributes them instead of needing each one placed by hand. The
/// strand advances by exactly one bead-spacing per count and the beads wrap,
/// which is what makes it look endless without drawing hundreds of them.
class TasbihStrand extends StatefulWidget {
  const TasbihStrand({
    required this.count,
    required this.target,
    required this.rounds,
    required this.colours,
    required this.onTap,
    this.signet = false,
    super.key,
  });

  final int count;
  final int target;
  final int rounds;

  /// Highlight, body and shadow — see `CounterStyle.beadColours`. Passed in
  /// rather than read from the theme so one widget serves every bead finish.
  final List<Color> colours;

  final VoidCallback onTap;

  /// The signet treatment: the mark stamped on every bead, and a laid navy
  /// rope in place of the thread the other finishes hang on. The mark's image
  /// is decoded once and only when such a strand is actually shown — the
  /// other finishes never pay for it.
  final bool signet;

  @override
  State<TasbihStrand> createState() => _TasbihStrandState();
}

class _TasbihStrandState extends State<TasbihStrand> {
  ui.Image? _emblem;

  @override
  void initState() {
    super.initState();
    if (widget.signet) _loadEmblem();
  }

  @override
  void didUpdateWidget(TasbihStrand old) {
    super.didUpdateWidget(old);
    if (widget.signet && _emblem == null) {
      _loadEmblem();
    } else if (!widget.signet && _emblem != null) {
      // Switching finishes reuses this State, so a decoded emblem outlived the
      // style that wanted it and every bead kept the mark — gold beads stamped
      // like signet ones. Loading it on the way in is only half the job.
      _emblem!.dispose();
      setState(() => _emblem = null);
    }
  }

  @override
  void dispose() {
    _emblem?.dispose();
    super.dispose();
  }

  /// Decoded small on purpose. The mark lands about a third of a bead wide, so
  /// a full-size decode of a 1705px asset would be held in memory for nothing.
  Future<void> _loadEmblem() async {
    final ByteData data = await rootBundle.load('assets/images/layla_mark.png');
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetHeight: 192,
    );
    final ui.FrameInfo frame = await codec.getNextFrame();
    if (!mounted) {
      frame.image.dispose();
      return;
    }
    setState(() => _emblem = frame.image);
  }

  @override
  Widget build(BuildContext context) {
    final int count = widget.count;
    final int target = widget.target;
    final int rounds = widget.rounds;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: TweenAnimationBuilder<double>(
        // Tween on the raw count so the strand slides between positions
        // rather than jumping. Fast, because a thumb counting at speed must
        // not be waiting on an animation.
        tween: Tween<double>(begin: count.toDouble(), end: count.toDouble()),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double travelled, _) => LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // The strand is drawn under the count, never through it: the
            // label's band is measured and the beads keep below it. On a
            // 6.1-inch phone in a sunnah routine the strand has about 150
            // points, and a 40-point numeral with a line under it took the
            // top 90 of them — so the label goes on one line there.
            final bool tight = constraints.maxHeight < 230;
            final double labelBand = tight ? 52 : 96;
            return CustomPaint(
              painter: _StrandPainter(
                travelled: travelled,
                colours: widget.colours,
                emblem: widget.signet ? _emblem : null,
                roped: widget.signet,
                top: labelBand,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          '$count',
                          style: AppType.clock.copyWith(
                            fontSize: tight ? 28 : 40,
                            color: AppColors.cream,
                          ),
                        ),
                        Text(
                          '/$target',
                          style: AppType.titleMd.copyWith(
                            color: AppColors.mist,
                          ),
                        ),
                        if (tight) ...<Widget>[
                          const SizedBox(width: 10),
                          Text(
                            rounds == 1 ? 'Round 1' : 'Rounds: $rounds',
                            style: AppType.bodySm.copyWith(
                              color: AppColors.mistFaint,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!tight)
                      Text(
                        rounds == 1 ? 'Round 1' : 'Rounds: $rounds',
                        style: AppType.bodySm.copyWith(
                          color: AppColors.mistFaint,
                        ),
                      ),
                    const Spacer(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StrandPainter extends CustomPainter {
  const _StrandPainter({
    required this.travelled,
    required this.colours,
    this.emblem,
    this.roped = false,
    this.top = 0,
  });

  /// The band at the top kept clear for the count; the strand runs below it.
  final double top;

  final List<Color> colours;

  /// The mark, stamped on every bead. Null until it has decoded, and for every
  /// finish that is not the signet — the beads simply go unstamped, rather
  /// than the strand refusing to draw.
  final ui.Image? emblem;

  /// Whether to lay a rope instead of a thread. Kept separate from [emblem]
  /// rather than read off it: the emblem arrives a frame or two late, and
  /// deriving the cord from it would swap thread for rope mid-decode in full
  /// view.
  final bool roped;

  /// The count, as a double so the strand can sit between beads mid-slide.
  final double travelled;

  /// Beads across the visible strand, the break aside.
  ///
  /// Six left only three on screen at any moment, each the size of a plum —
  /// three balls on a wire, not a misbaha. Bead size falls out of this: the
  /// radius is derived from the pitch, so raising the count shrinks the beads
  /// by the same factor and the cord between them survives untouched.
  static const double _span = 9.0;

  /// Bead diameter as a fraction of the pitch between them.
  ///
  /// A real misbaha is strung tight — the beads sit shoulder to shoulder and
  /// the cord only shows as a thread between them. At 0.72 they floated,
  /// evenly spaced dots on a wire. Just under 1 leaves a hairline of cord
  /// visible without letting them overlap.
  static const double _gap = 0.94;

  /// Half the break, as a fraction of the pitch.
  ///
  /// The strand is not a continuous rope: it is broken at one fixed point on
  /// the path — where the thumb sits — and each count pushes exactly one bead
  /// across the break. Unbroken, the whole strand just slid past and nothing
  /// marked the place the counting happened.
  static const double _breakHalf = 0.45;

  /// Where the break sits along the path. Just past halfway, which leaves
  /// roughly four and a half beads behind it and four in front.
  static const double _breakAt = 0.52;

  /// How sharply the break opens, in pitches.
  ///
  /// This is the whole trick. The break is a smooth widening of bead-space
  /// rather than a hole cut in it, so nothing has to be special-cased: a bead
  /// at rest sits clear of the break, and the one crossing runs about three
  /// times the speed of the rest on its way over — which is what a bead
  /// flicked past the thumb actually does.
  static const double _crossing = 0.18;

  /// Rope tones. Navy rather than the cream the hairline used: a real misbaha
  /// is strung on dark cord, and at this thickness it no longer needs to be
  /// pale to be seen.
  static const Color _cordEdge = Color(0xFF16233D);
  static const Color _cordBody = Color(0xFF33456B);
  static const Color _cordLay = Color(0x8C6E82AD);

  /// dart:math has no tanh, and this is the function the break is built on:
  /// flat either side, steep across the middle, and monotonic throughout so
  /// no bead can ever overtake its neighbour.
  static double _tanh(double x) {
    if (x > 10) return 1.0;
    if (x < -10) return -1.0;
    final double e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // The curve lives in the part of the canvas under the label; the bead
    // radius is added so the highest bead clears the band, not just the line.
    // A bead is about a twentieth of the width across, so that much is kept
    // free above and below: the strand then never leaves its own box, and on
    // a short one it cannot run into the line of text underneath.
    final double margin = size.width * 0.06;
    final double y0 = top + margin;
    final double h = math.max(1, size.height - top - 2 * margin);
    final Path path = Path()
      ..moveTo(-size.width * 0.1, y0 + h * 0.66)
      ..cubicTo(
        size.width * 0.25,
        y0 + h * 0.86,
        size.width * 0.55,
        y0 + h * 0.04,
        size.width * 1.1,
        y0 + h * 0.26,
      );

    final ui.PathMetric metric = path.computeMetrics().first;
    final double spacing = metric.length / (_span + 2 * _breakHalf);
    final double centre = metric.length * _breakAt;
    final double half = spacing * _breakHalf;
    final double soft = spacing * _crossing;

    if (roped) {
      _rope(canvas, path, metric, spacing);
    } else {
      // The other finishes keep the thread they were drawn for. A navy rope
      // under gold or pearl reads as the signet strand wearing a different
      // bead, which is not what those finishes are.
      canvas.drawPath(
        path,
        Paint()
          ..color = AppColors.mistFaint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }

    // Beads rest at half-pitch offsets either side of the break, so at rest
    // none of them is standing in it. One count carries every bead forward by
    // a pitch, which lands them back on the same offsets with the leader now
    // on the far side.
    final double frac = travelled - travelled.floorToDouble();
    final int reach = (metric.length / spacing / 2).ceil() + 2;

    for (int i = -reach; i <= reach; i++) {
      final double b = (i - 0.5 + frac) * spacing;
      final double at = centre + b + half * _tanh(b / soft);
      if (at < 0 || at > metric.length) continue;
      final ui.Tangent? t = metric.getTangentForOffset(at);
      if (t == null) continue;

      // Beads fade out at both ends rather than stopping dead at the edge.
      // They barely shrink doing it: a tightly strung strand whose end beads
      // taper reads as a tail, and a misbaha has no tail.
      final double scale = (math.min(at, metric.length - at) / (spacing * 0.6))
          .clamp(0.0, 1.0);
      if (scale <= 0.02) continue;
      final double r = spacing * _gap / 2 * (0.94 + 0.06 * scale);

      _bead(canvas, t.position, r, scale);
      if (emblem != null) _stamp(canvas, t.position, r, scale);
    }
  }

  void _bead(Canvas canvas, Offset c, double r, double opacity) {
    final Rect bounds = Rect.fromCircle(center: c, radius: r);

    // Contact shadow first, so a bead sits on the cord rather than hovering
    // over it. Offset down, because the light is up and to the left.
    canvas.drawCircle(
      c + Offset(0, r * 0.16),
      r * 0.94,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.40 * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.24),
    );

    // Body: lit from up and left, falling to the shadow tone at the rim.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.55),
          radius: 1.05,
          colors: <Color>[
            colours[0].withValues(alpha: opacity),
            colours[1].withValues(alpha: opacity),
            colours[2].withValues(alpha: opacity),
          ],
          stops: const <double>[0.0, 0.40, 1.0],
        ).createShader(bounds),
    );

    // Bounce light: a polished stone catches the surface under it and glows
    // faintly along the shaded edge. Skipping it is what made these read as
    // flat discs with a dot on them.
    canvas.drawCircle(
      c + Offset(r * 0.26, r * 0.30),
      r * 0.68,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.18
        ..color = colours[0].withValues(alpha: 0.26 * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.18),
    );

    // Rim, drawn inside the edge so it does not spill into the neighbour now
    // that the beads nearly touch.
    canvas.drawCircle(
      c,
      r * 0.95,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.10
        ..color = colours[2].withValues(alpha: 0.45 * opacity),
    );

    // Specular: a soft bloom with a hard bright core inside it. The bloom
    // alone is a smudge; the core alone is a sticker. Glass needs both.
    //
    // How hard the core is depends on the finish. The same white dot that
    // reads as a glint on pearl or gold sits on the navy signet bead like
    // something stuck to it, because the contrast against a dark body is so
    // much higher — so it is scaled by how light the bead actually is.
    final double gloss = 0.34 + 0.66 * colours[0].computeLuminance();
    canvas.drawCircle(
      c + Offset(-r * 0.32, -r * 0.36),
      r * 0.34,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.26 * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.20),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c + Offset(-r * 0.34, -r * 0.40),
        width: r * 0.38 * (0.66 + 0.34 * gloss),
        height: r * 0.28 * (0.66 + 0.34 * gloss),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.80 * gloss * opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.03),
    );
  }

  /// A laid rope, not a hairline.
  ///
  /// The cord was a 1.6px line, which put the whole weight of "this is strung"
  /// on something a bead could hide. It cannot: the length bared by the break
  /// is the most visible cord on the strand, and a pale thread there was the
  /// tell that this was drawn rather than strung.
  ///
  /// Three passes. A dark round body for the silhouette, a lighter core inset
  /// from its edges so the rope reads as round rather than flat, then the lay
  /// of it ticked across on the diagonal. The ticks are spaced by the rope's
  /// own width, which is what keeps the twist belonging to a rope of that
  /// thickness instead of looking like hatching drawn over it.
  void _rope(Canvas canvas, Path path, ui.PathMetric metric, double spacing) {
    final double w = spacing * 0.13;

    canvas.drawPath(
      path,
      Paint()
        ..color = _cordEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _cordBody
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.64
        ..strokeCap = StrokeCap.round,
    );

    final Paint lay = Paint()
      ..color = _cordLay
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.20
      ..strokeCap = StrokeCap.round;
    final double step = w * 0.60;
    for (double d = step / 2; d < metric.length; d += step) {
      final ui.Tangent? t = metric.getTangentForOffset(d);
      if (t == null) continue;
      final Offset dir = t.vector;
      final Offset nrm = Offset(-dir.dy, dir.dx);
      canvas.drawLine(
        t.position - nrm * (w * 0.29) - dir * (w * 0.25),
        t.position + nrm * (w * 0.29) + dir * (w * 0.25),
        lay,
      );
    }
  }

  /// The mark, pressed into the face of a bead.
  ///
  /// Drawn twice: a dark impression sunk a little below, then the gold over
  /// it. Flat gold rather than the art's own metal — at a third of a bead
  /// across, the texture only reads as noise.
  void _stamp(Canvas canvas, Offset c, double r, double opacity) {
    final ui.Image img = emblem!;
    final double h = r * 1.28;
    final double w = h * img.width / img.height;
    final Rect src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    final Rect dst = Rect.fromCenter(center: c, width: w, height: h);

    canvas.drawImageRect(
      img,
      src,
      dst.shift(Offset(0, r * 0.035)),
      Paint()
        ..colorFilter = ColorFilter.mode(
          Colors.black.withValues(alpha: 0.40 * opacity),
          BlendMode.srcIn,
        )
        ..filterQuality = FilterQuality.high,
    );
    canvas.drawImageRect(
      img,
      src,
      dst,
      Paint()
        ..colorFilter = ColorFilter.mode(
          AppColors.gold.withValues(alpha: opacity),
          BlendMode.srcIn,
        )
        ..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_StrandPainter old) =>
      old.travelled != travelled ||
      old.colours != colours ||
      old.emblem != emblem ||
      old.roped != roped ||
      old.top != top;
}
