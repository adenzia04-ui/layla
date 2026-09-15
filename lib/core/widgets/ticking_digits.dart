import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Digits that roll, and a colon that breathes.
///
/// Each changing digit drops in from above, settles, and — when its turn comes
/// again — carries on down and out. Motion blur runs along the travel, so the
/// movement reads as a wheel turning rather than as text being replaced.
///
/// Only the characters that actually changed move. Rolling the whole clock
/// every second would make the hour twitch in sympathy with the seconds, and a
/// screen that twitches once a second is worse than one that snaps.
class TickingDigits extends StatelessWidget {
  const TickingDigits({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 420),
  });

  final String value;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        for (int i = 0; i < value.length; i++)
          if (value[i] == ':')
            _Colon(key: ValueKey<int>(i), style: style)
          else
            _Glyph(
              // Keyed by position, so character N stays the same widget as it
              // changes and can animate instead of being rebuilt.
              key: ValueKey<int>(i),
              char: value[i],
              style: style,
              duration: duration,
            ),
      ],
    );
  }
}

/// The two dots, pulsing once a second.
///
/// Driven by its own repeating controller rather than by the clock's rebuilds:
/// the colon in "12:39" only changes value once a minute, so there is nothing
/// in the text itself to blink against.
class _Colon extends StatefulWidget {
  const _Colon({super.key, required this.style});

  final TextStyle style;

  @override
  State<_Colon> createState() => _ColonState();
}

class _ColonState extends State<_Colon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      // Never all the way out. A colon blinking to nothing reads as a fault —
      // the gap where a character should be — where a dim one reads as a pulse.
      opacity: Tween<double>(
        begin: 1,
        end: 0.28,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      // Two dots of our own, drawn over the font's colon made invisible.
      // The glyph keeps its width and its place on the baseline, and still
      // reads as ":" to anything that reads the clock as text; the dots sit
      // centred on the digits' height, which the glyph never did at this
      // size.
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Text(':', style: widget.style.copyWith(color: Colors.transparent)),
          Positioned.fill(
            child: CustomPaint(painter: _ColonPainter(style: widget.style)),
          ),
        ],
      ),
    );
  }
}

class _ColonPainter extends CustomPainter {
  const _ColonPainter({required this.style});

  final TextStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    // Measured, not guessed: where a digit's baseline and top actually fall
    // in this font at this size. A guess put the dots above the middle.
    final TextPainter probe = TextPainter(
      text: TextSpan(text: '0', style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final double baseline = probe.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final double top = baseline - (style.fontSize ?? 14) * 0.72;
    final double mid = (baseline + top) / 2;
    final double gap = (baseline - top) * 0.2;
    final double r = (style.fontSize ?? 14) * 0.055;
    final Paint p = Paint()..color = style.color ?? Colors.white;
    canvas.drawCircle(Offset(size.width / 2, mid - gap), r, p);
    canvas.drawCircle(Offset(size.width / 2, mid + gap), r, p);
  }

  @override
  bool shouldRepaint(_ColonPainter old) => old.style != style;
}

/// One character of the clock, rolling when it changes.
class _Glyph extends StatefulWidget {
  const _Glyph({
    super.key,
    required this.char,
    required this.style,
    required this.duration,
  });

  final String char;
  final TextStyle style;
  final Duration duration;

  @override
  State<_Glyph> createState() => _GlyphState();
}

class _GlyphState extends State<_Glyph> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  /// Assigned in `initState`, deliberately not as `late … = widget.char`: a
  /// late initialiser runs on first access, and the first access is inside
  /// `didUpdateWidget`, by which point `widget` is already the new value.
  late String _shown;
  late String _incoming;

  @override
  void initState() {
    super.initState();
    _shown = widget.char;
    _incoming = widget.char;
    _c.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _shown = _incoming;
          _c.reset();
        });
      }
    });
  }

  @override
  void didUpdateWidget(_Glyph old) {
    super.didUpdateWidget(old);
    if (widget.char == _incoming) return;
    // Mid-roll, the one on its way in becomes the one on its way out.
    if (_c.isAnimating) _shown = _incoming;
    _incoming = widget.char;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, _) {
        if (!_c.isAnimating) return Text(_shown, style: widget.style);
        final double t = Curves.easeOutCubic.transform(_c.value);
        final double travel = (widget.style.fontSize ?? 14) * 0.9;
        // Blur along the travel, strongest mid-flight: a wheel turning,
        // not text being replaced.
        final double blur = 4 * t * (1 - t) * 3;
        Widget rolling(String ch, double dy, double opacity) => Positioned.fill(
          child: Center(
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(sigmaY: blur),
                  child: Text(ch, style: widget.style),
                ),
              ),
            ),
          ),
        );
        return ClipRect(
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Sizes the box, invisibly, so the roll has room.
              Text(
                _incoming,
                style: widget.style.copyWith(color: Colors.transparent),
              ),
              rolling(_shown, t * travel, 1 - t),
              rolling(_incoming, (t - 1) * travel, t),
            ],
          ),
        );
      },
    );
  }
}
