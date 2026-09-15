import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../prayer_times/application/prayer_times_controller.dart';
import '../application/qibla_controller.dart';
import 'widgets/qibla_compass.dart';

class QiblaScreen extends ConsumerStatefulWidget {
  const QiblaScreen({super.key});

  @override
  ConsumerState<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends ConsumerState<QiblaScreen> {
  bool _lastAligned = false;
  double? _lastTickHeading;

  /// Haptics for someone holding the phone out in front of them, most likely
  /// not looking at the screen: a tick while it sweeps, a firm pulse on
  /// arrival.
  ///
  /// The ticks close up as the Kaaba gets nearer — 15° apart across open
  /// ground, 4° in the last stretch — so the sweep reads as warmer or colder
  /// by feel alone.
  void _pulse(QiblaState state, {required bool onScreen}) {
    final double? heading = state.heading;
    if (heading == null) return;

    // The shell keeps every tab alive in an IndexedStack, so this screen goes
    // on rebuilding with each compass reading while someone is over in Tasbih
    // — and it was buzzing in their hand the whole time they moved the phone.
    // Keep tracking the heading so returning does not fire a burst for all the
    // turning that happened while it was hidden, but stay silent.
    if (!onScreen) {
      _lastTickHeading = heading;
      _lastAligned = state.isAligned;
      return;
    }

    if (state.isAligned) {
      // No ticking once it is lined up. A degree or two of compass noise would
      // otherwise buzz away continuously in the hand of someone holding still.
      if (!_lastAligned) HapticFeedback.heavyImpact();
    } else {
      final double step = state.offBy > 60
          ? 15
          : state.offBy > 20
          ? 8
          : 4;
      final double? last = _lastTickHeading;
      if (last == null) {
        _lastTickHeading = heading;
      } else {
        // Shortest way round, so sweeping past north is a small step rather
        // than a 359° leap that would never tick.
        double moved = (heading - last).abs() % 360;
        if (moved > 180) moved = 360 - moved;
        if (moved >= step) {
          HapticFeedback.selectionClick();
          _lastTickHeading = heading;
        }
      }
    }
    _lastAligned = state.isAligned;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<QiblaState> qibla = ref.watch(qiblaProvider);
    final String place = ref.watch(placeProvider).valueOrNull?.label ?? '';

    return NightScaffold(
      ornamentHeight: 260,
      child: qibla.when(
        loading: () => const LoadingView(message: 'Finding the Qibla…'),
        error: (Object error, StackTrace stack) => ErrorView(
          message:
              'Layla Pro needs your location to work out the direction of the Kaaba.',
          onRetry: () => ref.invalidate(placeProvider),
        ),
        data: (QiblaState state) {
          _pulse(state, onScreen: TickerMode.valuesOf(context).enabled);
          // Gaps give way before content does — see fitGap. This screen does
          // not scroll either, and at 1.3x text on an SE it ran 45px past the
          // bottom: the distance line was the part that went.
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double gap = fitGap(context, constraints);
              return Column(
                children: <Widget>[
                  SizedBox(height: Insets.sm * gap),
                  // The way out rides in the title row rather than above it.
                  // On its own line it cost 48px, and this screen does not
                  // scroll — an SE at 1.0x overflowed by 26.
                  Row(
                    children: <Widget>[
                      CircleIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        tooltip: 'Back',
                        onPressed: () => context.pop(),
                      ),
                      Expanded(
                        child: Text(
                          'Qibla',
                          textAlign: TextAlign.center,
                          style: AppType.displayLg,
                        ),
                      ),
                      // Balances the button so the title sits centred.
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: Insets.sm),
                  _PlacePill(place: place),
                  const Spacer(),
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) =>
                            QiblaCompass(
                              heading: state.heading,
                              qiblaBearing: state.qiblaBearing,
                              aligned: state.isAligned,
                              size: constraints.maxWidth.clamp(220, 330),
                            ),
                  ),
                  SizedBox(height: Insets.xxl * gap),
                  _ReadoutRow(state: state),
                  SizedBox(height: Insets.xl * gap),
                  _StatusBanner(state: state),
                  const Spacer(),
                  Text(
                    '${state.distanceKm.round()} km to the Kaaba',
                    style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                  ),
                  SizedBox(height: Insets.xxl * gap),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Where you are, as a tappable-looking pill rather than loose text.
class _PlacePill extends StatelessWidget {
  const _PlacePill({required this.place});

  final String place;

  @override
  Widget build(BuildContext context) {
    final bool known = place.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.navyElevated,
        borderRadius: Radii.chip,
        border: Border.all(color: AppColors.navyLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            known ? Icons.near_me_rounded : Icons.near_me_disabled_rounded,
            size: 15,
            color: known ? AppColors.gold : AppColors.mistFaint,
          ),
          const SizedBox(width: Insets.sm),
          // A bearing is only true from a place, so the place belongs next to
          // it rather than in a caption underneath.
          Text(
            known ? place : 'Point your phone flat and level',
            style: AppType.bodySm.copyWith(color: AppColors.cream),
          ),
        ],
      ),
    );
  }
}

class _ReadoutRow extends StatelessWidget {
  const _ReadoutRow({required this.state});

  final QiblaState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        _Readout(
          label: 'Qibla',
          value: '${state.qiblaBearing.toStringAsFixed(1)}°',
          detail: state.compassPoint,
        ),
        Container(height: 34, width: 1, color: AppColors.navyLine),
        _Readout(
          label: 'Facing',
          value: state.heading == null
              ? '—'
              : '${state.heading!.toStringAsFixed(0)}°',
          detail: state.hasSensor ? 'device heading' : 'no compass',
        ),
        Container(height: 34, width: 1, color: AppColors.navyLine),
        _Readout(
          label: 'Off by',
          value: state.hasSensor ? '${state.offBy.toStringAsFixed(0)}°' : '—',
          detail: state.isAligned ? 'aligned' : 'keep turning',
        ),
      ],
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.label,
    required this.value,
    required this.detail,
  });

  final String label;
  final String value;
  final String detail;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      Text(
        label.toUpperCase(),
        style: AppType.label.copyWith(color: AppColors.gold),
      ),
      const SizedBox(height: 4),
      Text(value, style: AppType.numeral.copyWith(fontSize: 20)),
      const SizedBox(height: 2),
      Text(
        detail,
        style: AppType.bodySm.copyWith(
          fontSize: 11,
          color: AppColors.mistFaint,
        ),
      ),
    ],
  );
}

/// One clear sentence about what to do next — aligned, keep turning, calibrate,
/// or no sensor at all.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state});

  final QiblaState state;

  @override
  Widget build(BuildContext context) {
    final ({Color color, IconData icon, String text}) look = switch (state) {
      final QiblaState s when !s.hasSensor => (
        color: AppColors.amber,
        icon: Icons.explore_off_outlined,
        text:
            'This device has no compass. Face '
            '${s.qiblaBearing.toStringAsFixed(0)}° (${s.compassPoint}) '
            'using another compass.',
      ),
      final QiblaState s when s.needsCalibration => (
        color: AppColors.amber,
        icon: Icons.rotate_right_rounded,
        text:
            'Compass needs calibrating — move your phone in a figure of '
            'eight a few times.',
      ),
      final QiblaState s when s.isAligned => (
        color: AppColors.emerald,
        icon: Icons.check_circle_rounded,
        text: 'You are facing the Qibla.',
      ),
      _ => (
        color: AppColors.gold,
        icon: Icons.rotate_left_rounded,
        text: 'Turn until the marker meets the top of the dial.',
      ),
    };

    return AnimatedContainer(
      duration: Motion.fast,
      width: double.infinity,
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: look.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: look.color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          Icon(look.icon, color: look.color, size: 20),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              look.text,
              style: AppType.bodySm.copyWith(color: AppColors.cream),
            ),
          ),
        ],
      ),
    );
  }
}
