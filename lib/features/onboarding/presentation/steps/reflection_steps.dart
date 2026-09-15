import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../application/journey_controller.dart';
import '../../domain/journey_answers.dart';
import '../journey_step.dart';
import '../widgets/journey_chrome.dart';

/// Hours a day on the phone, set on a dial of lit ticks.
///
/// A dial rather than a bare slider because the number is about to be
/// multiplied by 365 and then by a lifetime, and a figure someone has watched
/// themselves choose is one they will argue with rather than dismiss.
class PhoneHoursStep extends JourneyStep {
  const PhoneHoursStep();

  static const int _max = 12;

  @override
  String title(JourneyAnswers a) =>
      'How many hours a day are you on your phone?';

  /// The default counts as an answer, because the dial is already showing it.
  ///
  /// This read `phoneHoursADay != null`, while the dial displayed
  /// `phoneHoursADay ?? 3`. Anyone who agreed with the three hours on screen
  /// and reached for Next found it dead, with nothing to explain why — the
  /// screen was showing a number it had not recorded. [_Dial] now writes the
  /// default on arrival, so what is shown and what is stored are the same
  /// thing.
  @override
  bool answered(JourneyAnswers a) => true;

  @override
  Widget body(BuildContext context, WidgetRef ref, JourneyAnswers a) =>
      _Dial(answers: a);
}

class _Dial extends ConsumerStatefulWidget {
  const _Dial({required this.answers});

  final JourneyAnswers answers;

  @override
  ConsumerState<_Dial> createState() => _DialState();
}

class _DialState extends ConsumerState<_Dial> {
  static const int _default = 3;

  @override
  void initState() {
    super.initState();
    // Once, on arrival — not in build, which would fight every drag.
    if (widget.answers.phoneHoursADay == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(journeyProvider).phoneHoursADay == null) {
          ref.read(journeyProvider.notifier).setPhoneHours(_default);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final JourneyAnswers a = ref.watch(journeyProvider);
    final JourneyController c = ref.read(journeyProvider.notifier);
    final int hours = a.phoneHoursADay ?? _default;

    return Column(
      children: <Widget>[
        const SizedBox(height: Insets.xl),
        SizedBox(
          height: 250,
          width: 250,
          child: CustomPaint(
            painter: _DialPainter(value: hours / PhoneHoursStep._max),
            child: Center(
              child: Text(
                '$hours hr',
                style: AppType.clock.copyWith(
                  fontSize: 48,
                  color: AppColors.gold,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: Insets.xxl),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: AppColors.gold,
            inactiveTrackColor: AppColors.navyLine,
            thumbColor: AppColors.goldSoft,
            overlayColor: AppColors.gold.withValues(alpha: 0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
          ),
          child: Slider(
            value: hours.toDouble(),
            min: 1,
            max: PhoneHoursStep._max.toDouble(),
            divisions: PhoneHoursStep._max - 1,
            onChanged: (double v) {
              if (v.round() != hours) HapticFeedback.selectionClick();
              c.setPhoneHours(v.round());
            },
          ),
        ),
      ],
    );
  }
}

/// Ticks around a circle, lit up to the chosen value.
///
/// Drawn rather than assembled from rotated widgets: twelve Transforms that
/// rebuild on every drag frame is a lot of layout for something a single
/// canvas pass covers.
class _DialPainter extends CustomPainter {
  const _DialPainter({required this.value});

  /// 0..1.
  final double value;

  static const int _ticks = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double outer = size.width / 2 - 4;
    final double inner = outer - 22;

    for (int i = 0; i < _ticks; i++) {
      // From the top, clockwise.
      final double t = i / _ticks;
      final double angle = -math.pi / 2 + t * 2 * math.pi;
      final bool lit = t <= value;
      final Offset a = c + Offset(math.cos(angle), math.sin(angle)) * inner;
      final Offset b = c + Offset(math.cos(angle), math.sin(angle)) * outer;
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = lit ? AppColors.gold : AppColors.navyLine
          ..strokeWidth = lit ? 3.4 : 2.4
          ..strokeCap = StrokeCap.round
          // The lit run glows; the unlit run must not, or the whole dial
          // hazes over and the boundary between them disappears.
          ..maskFilter = lit
              ? const MaskFilter.blur(BlurStyle.solid, 2.5)
              : null,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.value != value;
}

/// The arithmetic, said plainly.
///
/// This is the one screen that raises its voice, and it does it with a
/// number rather than an adjective. The lifetime figure states its own
/// assumption in the copy — a projection that hides its horizon is a trick,
/// and a trick is a poor way to begin.
class ReflectionStep extends JourneyStep {
  const ReflectionStep();

  @override
  String title(JourneyAnswers a) => '';

  @override
  bool answered(JourneyAnswers a) => true;

  @override
  bool get bare => true;

  @override
  String label(JourneyAnswers a) => 'I see';

  @override
  Widget body(BuildContext context, WidgetRef ref, JourneyAnswers a) {
    final String who = a.name.trim().isEmpty ? 'You' : a.name.trim();
    final int hours = a.phoneHoursAYear ?? 0;
    final int days = a.phoneDaysAYear ?? 0;
    final int years = a.phoneYearsALifetime ?? 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AccentedText(<String>[
          '$who, that is about ',
          '$hours hours',
          ' on your phone this year.',
        ], style: AppType.displayMd),
        const SizedBox(height: Insets.xxl),
        AccentedText(<String>[
          'That is ',
          '$days days',
          ' a year.',
        ], style: AppType.displayMd),
        const SizedBox(height: Insets.xxl),
        AccentedText(<String>[
          'Held for fifty more years, ',
          '$years years',
          ' of a life.',
        ], style: AppType.displayMd),
        const SizedBox(height: Insets.xxxl),
        Text(
          'How much of it brings you closer to Allah?',
          style: AppType.body.copyWith(color: AppColors.mist),
        ),
      ],
    );
  }
}
