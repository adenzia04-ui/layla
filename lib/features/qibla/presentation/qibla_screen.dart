import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
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

  /// A single haptic tap the moment the phone lines up — the user is holding
  /// the phone in front of them and may not be looking at the screen.
  void _pulseOnAlign(bool aligned) {
    if (aligned && !_lastAligned) HapticFeedback.mediumImpact();
    _lastAligned = aligned;
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<QiblaState> qibla = ref.watch(qiblaProvider);
    final String place = ref.watch(placeProvider).value?.label ?? '';

    return NightScaffold(
      ornamentHeight: 260,
      child: qibla.when(
        loading: () => const LoadingView(message: 'Finding the Qibla…'),
        error: (Object error, StackTrace stack) => ErrorView(
          message:
              'Layla needs your location to work out the direction of the Kaaba.',
          onRetry: () => ref.invalidate(placeProvider),
        ),
        data: (QiblaState state) {
          _pulseOnAlign(state.isAligned);
          return Column(
            children: <Widget>[
              const SizedBox(height: Insets.lg),
              Text('Qibla', style: AppType.displayLg),
              const SizedBox(height: 4),
              Text(
                place.isEmpty ? 'Point your phone flat and level' : place,
                style: AppType.bodySm.copyWith(color: AppColors.mist),
              ),
              const Spacer(),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) =>
                    QiblaCompass(
                  heading: state.heading,
                  qiblaBearing: state.qiblaBearing,
                  aligned: state.isAligned,
                  size: constraints.maxWidth.clamp(220, 330),
                ),
              ),
              const SizedBox(height: Insets.xxl),
              _ReadoutRow(state: state),
              const SizedBox(height: Insets.xl),
              _StatusBanner(state: state),
              const Spacer(),
              Text(
                '${state.distanceKm.round()} km to the Kaaba',
                style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
              ),
              const SizedBox(height: Insets.xxl),
            ],
          );
        },
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
            style: AppType.bodySm
                .copyWith(fontSize: 11, color: AppColors.mistFaint),
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
          text: 'This device has no compass. Face '
              '${s.qiblaBearing.toStringAsFixed(0)}° (${s.compassPoint}) '
              'using another compass.',
        ),
      final QiblaState s when s.needsCalibration => (
          color: AppColors.amber,
          icon: Icons.rotate_right_rounded,
          text: 'Compass needs calibrating — move your phone in a figure of '
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
