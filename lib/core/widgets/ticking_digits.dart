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
      opacity: Tween<double>(begin: 1, end: 0.28).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Text(':', style: widget.style),
    );
  }
}

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

  /// Assigned in `initState`, deliberately not as `late … = widget.char`. A
  /// late initialiser runs on *first access*, and the first access is inside
  /// `didUpdateWidget` — by which point `widget` is already the new value, so
  /// the field initialised to the incoming character and compared equal to
  /// itself. The animation silently never ran.
  late String _shown;
  late String _incoming;

  @override
  void initState() {
    super.initState();
    _shown = widget.char;
    _incoming = widget.char;
    _c.addStatusListener((AnimationStatus s) {
      if (s != AnimationStatus.completed) return;
      // Adopt the new glyph and wind back to rest. At value 1 the outgoing
      // layer is fully faded and the incoming one has become the shown glyph,
      // so leaving the controller there renders nothing at all.
      setState(() => _shown = _incoming);
      _c.value = 0;
    });
  }

  @override
  void didUpdateWidget(_Glyph old) {
    super.didUpdateWidget(old);
    if (widget.char == _incoming) return;
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
        final double t = Curves.easeInOutCubic.transform(_c.value);
        final bool moving = t > 0.001 && t < 0.999;

        // How far a digit travels. Enough to read as leaving the frame, not so
        // far that it flies past the neighbouring characters.
        // A shade under a full glyph height. Less than this and the two
        // digits sit on top of each other halfway through, which reads as a
        // smudge rather than as one replacing the other.
        final double travel = (widget.style.fontSize ?? 20) * 0.95;

        // Clipped to the character's own box, so digits appear and vanish at
        // its edges like a wheel behind a window. Without this they simply
        // float over whatever sits above and below — `Transform` moves paint,
        // not layout — and a digit would slide across the prayer name.
        return ClipRect(
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Leaving: continues downward, blurring as it goes.
              if (t < 1)
                _layer(
                  char: _shown,
                  dy: t * travel,
                  opacity: (1 - t) * (1 - t),
                  blur: t,
                  moving: moving,
                ),
              // Arriving: drops in from above and sharpens as it lands.
              if (t > 0 && _incoming != _shown)
                _layer(
                  char: _incoming,
                  dy: -(1 - t) * travel,
                  opacity: t * t,
                  blur: 1 - t,
                  moving: moving,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _layer({
    required String char,
    required double dy,
    required double opacity,
    required double blur,
    required bool moving,
  }) {
    Widget text = Text(char, style: widget.style);

    if (moving && blur > 0.02) {
      // Along the direction of travel only. Blurring sideways as well would
      // just make the digit look out of focus instead of in motion.
      text = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: 0.4 * blur,
          sigmaY: 7 * blur,
          tileMode: TileMode.decal,
        ),
        child: text,
      );
    }

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.translate(offset: Offset(0, dy), child: text),
    );
  }
}
