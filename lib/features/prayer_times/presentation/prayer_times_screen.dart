import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/mihrab_arch.dart';
import '../../../core/widgets/state_views.dart';
import '../../streaks/application/streak_controller.dart';
import '../../streaks/domain/prayer_day.dart';
import '../application/prayer_times_controller.dart';
import '../data/prayer_settings_repository.dart';
import '../domain/prayer.dart';
import '../domain/prayer_settings.dart';

/// The full day, in the curved-header style of the fourth reference: a domed
/// header with the running countdown, then every prayer as a row with its own
/// reminder toggle.
class PrayerTimesScreen extends ConsumerWidget {
  const PrayerTimesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PrayerSchedule> schedule =
        ref.watch(prayerScheduleProvider);
    final AsyncValue<PrayerMoment> moment = ref.watch(prayerMomentProvider);
    final DateTime now = ref.watch(clockProvider).value ?? DateTime.now();
    final PrayerSettings settings = ref.watch(prayerSettingsProvider);
    final PrayerDay day = ref.watch(todayPrayerDayProvider).value ??
        PrayerDay.empty(Fmt.dayId(now));
    final String place = ref.watch(placeProvider).value?.label ?? '';

    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: schedule.when(
        loading: () => const LoadingView(message: 'Calculating…'),
        error: (Object error, StackTrace stack) => ErrorView(
          message: 'Prayer times need your location.',
          onRetry: () => ref.invalidate(placeProvider),
        ),
        data: (PrayerSchedule s) => CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: _CurvedHeader(
                schedule: s,
                moment: moment.value,
                now: now,
                place: place,
                use24h: settings.use24hClock,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.page,
                  Insets.xl,
                  Insets.page,
                  Insets.xxxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text('Today', style: AppType.displaySm),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => context.push(Routes.prayerSettings),
                          icon: const Icon(Icons.tune_rounded, size: 17),
                          label: const Text('Settings'),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.sm),
                    NightCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.lg,
                        vertical: Insets.xs,
                      ),
                      child: Column(
                        children: <Widget>[
                          for (final PrayerSlot slot in s.slots)
                            _PrayerRow(
                              slot: slot,
                              isActive: s.currentAt(now)?.id == slot.id,
                              status: day.recordFor(slot.id).status,
                              settings: settings,
                              use24h: settings.use24hClock,
                              onToggleNotification: slot.id == PrayerId.sunrise
                                  ? null
                                  : () => ref
                                      .read(prayerSettingsRepositoryProvider)
                                      .setNotification(
                                        settings,
                                        slot.id,
                                        enabled: !settings.notifies(slot.id),
                                      ),
                            ),
                          _TahajjudRow(
                            window: s.tahajjud,
                            now: now,
                            use24h: settings.use24hClock,
                            prayed: day.tahajjudPrayed,
                            onTap: () => context.go(Routes.tahajjud),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                    _MethodFooter(settings: settings),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The domed header: gradient of the current prayer, arch silhouette, and the
/// live countdown to the next one.
class _CurvedHeader extends StatelessWidget {
  const _CurvedHeader({
    required this.schedule,
    required this.moment,
    required this.now,
    required this.place,
    required this.use24h,
  });

  final PrayerSchedule schedule;
  final PrayerMoment? moment;
  final DateTime now;
  final String place;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final PrayerSlot? current = schedule.currentAt(now);
    final PrayerPalette palette =
        (current?.id ?? PrayerId.fajr).palette;

    return ClipPath(
      clipper: _DomeClipper(),
      child: Container(
        height: 320,
        decoration: BoxDecoration(gradient: palette.gradient),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(top: 60),
                child: MihrabGlow(color: palette.onSurface, opacity: 0.2),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Insets.page),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        CircleIconButton(
                          icon: Icons.arrow_back_ios_new_rounded,
                          onPressed: () => context.pop(),
                          background:
                              palette.onSurface.withValues(alpha: 0.16),
                          foreground: palette.onSurface,
                        ),
                        const Spacer(),
                        if (place.isNotEmpty)
                          Row(
                            children: <Widget>[
                              Icon(Icons.place_outlined,
                                  size: 14, color: palette.onSurface,),
                              const SizedBox(width: 4),
                              Text(
                                place,
                                style: AppType.bodySm
                                    .copyWith(color: palette.onSurface),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: Insets.lg),
                    Text(
                      'Prayer times',
                      style: AppType.displayLg
                          .copyWith(color: palette.onSurface),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      Fmt.dayDate(now),
                      style: AppType.bodySm.copyWith(
                        color: palette.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      Fmt.hijri(now),
                      style: AppType.bodySm.copyWith(
                        color: palette.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: Insets.lg),
                    if (moment != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Insets.lg,
                          vertical: Insets.sm,
                        ),
                        decoration: BoxDecoration(
                          color: palette.onSurface.withValues(alpha: 0.16),
                          borderRadius: Radii.chip,
                          border: Border.all(
                            color: palette.onSurface.withValues(alpha: 0.26),
                          ),
                        ),
                        child: Text(
                          '${moment!.next.id.label} in '
                          '${Fmt.countdown(moment!.untilNext(now))}',
                          style: AppType.numeral
                              .copyWith(color: palette.onSurface),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The organic curved bottom edge from the fourth reference.
class _DomeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path()
      ..lineTo(0, size.height - 60)
      ..quadraticBezierTo(
        size.width * 0.24,
        size.height,
        size.width * 0.62,
        size.height - 24,
      )
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height - 44,
        size.width,
        size.height - 92,
      )
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(_DomeClipper oldClipper) => false;
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.slot,
    required this.isActive,
    required this.status,
    required this.settings,
    required this.use24h,
    this.onToggleNotification,
  });

  final PrayerSlot slot;
  final bool isActive;
  final PrayerStatus status;
  final PrayerSettings settings;
  final bool use24h;
  final VoidCallback? onToggleNotification;

  @override
  Widget build(BuildContext context) {
    final bool isSunrise = slot.id == PrayerId.sunrise;
    final bool notifies = settings.notifies(slot.id);
    final int adjust = settings.adjustmentFor(slot.id);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: Insets.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.navyLine.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isActive ? slot.id.palette.gradient : null,
              color: isActive ? null : AppColors.navyElevated,
              border: Border.all(
                color: isActive ? AppColors.gold : AppColors.navyLine,
              ),
            ),
            child: Icon(
              slot.id.icon,
              size: 17,
              color: isActive ? slot.id.palette.onSurface : AppColors.mist,
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      slot.id.label,
                      style: AppType.titleMd.copyWith(
                        color: isSunrise ? AppColors.mist : AppColors.cream,
                      ),
                    ),
                    if (isActive) ...<Widget>[
                      const SizedBox(width: Insets.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 1,
                        ),
                        decoration: const BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: Radii.chip,
                        ),
                        child: Text(
                          'NOW',
                          style: AppType.label.copyWith(
                            fontSize: 9,
                            color: AppColors.midnight,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (adjust != 0)
                  Text(
                    '${adjust > 0 ? '+' : ''}$adjust min adjustment',
                    style: AppType.bodySm.copyWith(
                      fontSize: 11,
                      color: AppColors.goldDim,
                    ),
                  ),
              ],
            ),
          ),
          if (!isSunrise && status == PrayerStatus.completed)
            const Padding(
              padding: EdgeInsets.only(right: Insets.sm),
              child: Icon(Icons.check_circle,
                  size: 16, color: AppColors.emerald,),
            ),
          Text(
            Fmt.time(slot.start, use24h: use24h),
            style: AppType.numeral.copyWith(
              color: isSunrise ? AppColors.mist : AppColors.cream,
            ),
          ),
          if (onToggleNotification != null)
            IconButton(
              onPressed: onToggleNotification,
              iconSize: 19,
              color: notifies ? AppColors.gold : AppColors.mistFaint,
              tooltip: notifies ? 'Turn reminder off' : 'Turn reminder on',
              icon: Icon(
                notifies
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
              ),
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _TahajjudRow extends StatelessWidget {
  const _TahajjudRow({
    required this.window,
    required this.now,
    required this.use24h,
    required this.prayed,
    required this.onTap,
  });

  final TahajjudWindow window;
  final DateTime now;
  final bool use24h;
  final bool prayed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool active = window.isActiveAt(now);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.md),
        child: Row(
          children: <Widget>[
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: active ? PrayerPalette.tahajjud.gradient : null,
                color: active ? null : AppColors.navyElevated,
                border: Border.all(
                  color: active ? AppColors.gold : AppColors.goldDim,
                ),
              ),
              child: const Icon(Icons.bedtime_rounded,
                  size: 17, color: AppColors.goldSoft,),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Tahajjud', style: AppType.titleMd),
                  Text(
                    'Last third of the night · until '
                    '${Fmt.time(window.end, use24h: use24h)}',
                    style: AppType.bodySm.copyWith(
                      fontSize: 11,
                      color: AppColors.mistFaint,
                    ),
                  ),
                ],
              ),
            ),
            if (prayed)
              const Padding(
                padding: EdgeInsets.only(right: Insets.sm),
                child:
                    Icon(Icons.check_circle, size: 16, color: AppColors.emerald),
              ),
            Text(
              Fmt.time(window.start, use24h: use24h),
              style: AppType.numeral.copyWith(color: AppColors.goldSoft),
            ),
            const SizedBox(width: Insets.md),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.mistFaint,),
          ],
        ),
      ),
    );
  }
}

class _MethodFooter extends StatelessWidget {
  const _MethodFooter({required this.settings});

  final PrayerSettings settings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(Icons.calculate_outlined,
            size: 15, color: AppColors.mistFaint,),
        const SizedBox(width: Insets.sm),
        Expanded(
          child: Text(
            'Calculated with ${settings.method.label} · '
            '${settings.madhab.label} for Asr',
            style: AppType.bodySm
                .copyWith(fontSize: 11, color: AppColors.mistFaint),
          ),
        ),
      ],
    );
  }
}
