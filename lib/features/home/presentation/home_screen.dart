import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../shell/app_shell.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/noor_flame.dart';
import '../../../core/widgets/noor_globe.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../prayer_times/application/prayer_times_controller.dart';
import '../../prayer_times/domain/prayer.dart';
import '../../streaks/application/streak_controller.dart';
import '../../streaks/domain/prayer_day.dart';
import '../../tahajjud/application/tahajjud_controller.dart';
import 'widgets/feature_rail.dart';
import 'widgets/next_prayer_hero.dart';
import 'widgets/prayer_grid.dart';
import 'widgets/today_progress_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the OS alarm queue in step with the computed schedule.

    final AppUser? user = ref.watch(appUserProvider).value;
    final AsyncValue<NoorPlace> place = ref.watch(placeProvider);
    final AsyncValue<PrayerSchedule> schedule =
        ref.watch(prayerScheduleProvider);
    final AsyncValue<PrayerMoment> moment = ref.watch(prayerMomentProvider);
    final DateTime now = ref.watch(clockProvider).value ?? DateTime.now();
    final PrayerDay day =
        ref.watch(todayPrayerDayProvider).value ?? PrayerDay.empty(Fmt.dayId(now));
    final bool use24h = ref.watch(prayerSettingsProvider).use24hClock;
    final int liveTahajjud = ref.watch(tahajjudLiveCountProvider).value ?? 0;

    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.nightSky),
            ),
          ),
          // The globe sits behind the greeting and the prayer card, fading out
          // before the content below so nothing competes with the times. Its
          // colour follows whichever prayer is running, so the screen tracks
          // the sky outside — gold at Maghrib, deep and quiet at Isha.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // Tall enough that the Earth's lower limb passes behind the
            // hero, which is what lets the type sit *on* the planet rather
            // than on a slab below it. `centreY` compensates so growing the
            // box does not drag the globe down with it.
            height: 820,
            // The sphere is taller than this band, and `Positioned` does not
            // clip. Without this, the overflow escapes the ShaderMask — which
            // only masks inside its own box — and repaints at full opacity
            // exactly where the fade reached zero, drawing a hard seam across
            // the Earth.
            child: ClipRect(
              child: ShaderMask(
                shaderCallback: (Rect bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: <double>[0, 0.62, 0.9],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: NoorGlobe(
                  prayer: moment.value?.current?.id,
                  latitude: place.value?.lat,
                  longitude: place.value?.lng,
                  radiusFactor: 0.60,
                  centreY: 0.42,
                ),
              ),
            ),
          ),

          // No ornament layer here on purpose. The gold garland and the
          // hanging lanterns cut straight across the Earth and read as
          // scratches on it — the globe is the ornament on this screen. The
          // lanterns still appear on every other night-themed screen.
          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              color: AppColors.gold,
              backgroundColor: AppColors.navyElevated,
              onRefresh: () async => ref.refresh(placeProvider.future),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Insets.page,
                  Insets.sm,
                  Insets.page,
                  // Clears the translucent tab bar, which the content now
                  // scrolls underneath.
                  Insets.xxxl + kBottomBarHeight,
                ),
                children: <Widget>[
                  _Greeting(user: user, now: now, place: place.value),
                  const SizedBox(height: Insets.xl),
                  _HeroSection(
                    schedule: schedule,
                    moment: moment,
                    now: now,
                    use24h: use24h,
                    locationLabel: place.value?.label ?? 'Locating…',
                    onRetryLocation: () => ref.invalidate(placeProvider),
                  ),
                  const SizedBox(height: Insets.lg),
                  if (schedule.hasValue)
                    PrayerGrid(
                      schedule: schedule.requireValue,
                      now: now,
                      day: day,
                      use24h: use24h,
                      onTapPrayer: (PrayerId id) => context.push(
                        id == PrayerId.tahajjud
                            ? Routes.tahajjud
                            : Routes.prayerTimes,
                      ),
                    ),
                  const SizedBox(height: Insets.xl),
                  TodayProgressCard(
                    day: day,
                    currentStreak: ref.watch(userStatsProvider).currentStreak,
                    onTap: () => context.push(Routes.streak),
                  ),
                  const SizedBox(height: Insets.xl),
                  const SectionHeader(label: 'Main features'),
                  FeatureRail(
                    items: <FeatureItem>[
                      FeatureItem(
                        label: 'Prayer Times',
                        icon: Icons.access_time_rounded,
                        // Qiyam and sujud rather than a clock face. The palette
                        // is already Layla's — gold standing, grey prostrate —
                        // so it sits in the rail without any recolouring.
                        iconWidget: Image.asset(
                          'assets/images/prayer_postures.png',
                          width: 50,
                          height: 50,
                          filterQuality: FilterQuality.medium,
                        ),
                        onTap: () => context.push(Routes.prayerTimes),
                      ),
                      FeatureItem(
                        label: 'Qibla',
                        icon: Icons.explore_rounded,
                        accent: PrayerPalette.asr.start,
                        // The Kaaba emblem rather than a compass glyph. It is
                        // given more of the chip than a line icon gets — the
                        // artwork carries its own edge, so it does not need
                        // the tinted square around it for definition.
                        iconWidget: Image.asset(
                          'assets/images/qibla_kaaba.png',
                          width: 50,
                          height: 50,
                          filterQuality: FilterQuality.medium,
                        ),
                        onTap: () => context.go(Routes.qibla),
                      ),
                      FeatureItem(
                        label: 'Tasbih',
                        icon: Icons.radio_button_checked_rounded,
                        accent: AppColors.emerald,
                        iconWidget: Image.asset(
                          'assets/images/tasbih_hands.png',
                          width: 50,
                          height: 50,
                          filterQuality: FilterQuality.medium,
                        ),
                        onTap: () => context.go(Routes.tasbih),
                      ),
                      FeatureItem(
                        label: 'Tahajjud',
                        icon: Icons.bedtime_rounded,
                        accent: PrayerPalette.maghrib.end,
                        badge: liveTahajjud > 0 ? '$liveTahajjud' : null,
                        onTap: () => context.go(Routes.tahajjud),
                      ),
                      FeatureItem(
                        label: 'Tahajjud Stories',
                        icon: Icons.menu_book_rounded,
                        accent: AppColors.goldSoft,
                        onTap: () => context.go(Routes.stories),
                      ),
                      FeatureItem(
                        label: 'Prayer Streak',
                        icon: Icons.local_fire_department_rounded,
                        accent: AppColors.ember,
                        iconWidget: const NoorFlame(size: 26, glow: false),
                        onTap: () => context.push(Routes.streak),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.xl),
                  if (schedule.hasValue)
                    _TahajjudTonightCard(
                      window: schedule.requireValue.tahajjud,
                      now: now,
                      use24h: use24h,
                      liveCount: liveTahajjud,
                      onTap: () => context.go(Routes.tahajjud),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.user, required this.now, this.place});

  final AppUser? user;
  final DateTime now;
  final NoorPlace? place;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Assalamu alaikum',
                style: AppType.bodySm.copyWith(color: AppColors.mist),
              ),
              const SizedBox(height: 2),
              Text(
                user?.firstName ?? 'friend',
                style: AppType.displayLg,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: Insets.sm),
              Text(
                Fmt.dayDate(now),
                style: AppType.bodySm.copyWith(color: AppColors.mist),
              ),
              Text(
                Fmt.hijri(now),
                style: AppType.bodySm.copyWith(color: AppColors.goldDim),
              ),
            ],
          ),
        ),
        const SizedBox(width: Insets.md),
        CircleIconButton(
          icon: Icons.settings_outlined,
          tooltip: 'Prayer settings',
          onPressed: () => context.push(Routes.prayerSettings),
        ),
      ],
    );
  }
}

/// Wraps the hero in the three states location can be in: resolved, loading,
/// or blocked by permission — the last one gets an actionable card rather than
/// a bare error.
class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.schedule,
    required this.moment,
    required this.now,
    required this.use24h,
    required this.locationLabel,
    required this.onRetryLocation,
  });

  final AsyncValue<PrayerSchedule> schedule;
  final AsyncValue<PrayerMoment> moment;
  final DateTime now;
  final bool use24h;
  final String locationLabel;
  final VoidCallback onRetryLocation;

  @override
  Widget build(BuildContext context) {
    if (schedule.hasError) {
      return _LocationNeededCard(
        message: AppFailure.from(schedule.error!).message,
        onRetry: onRetryLocation,
      );
    }
    if (!schedule.hasValue || !moment.hasValue) {
      return const SizedBox(
        height: 300,
        child: LoadingView(message: 'Working out your prayer times…'),
      );
    }

    final PrayerSchedule s = schedule.requireValue;
    final PrayerMoment m = moment.requireValue;

    // The prayer after next, for the bottom-right slot.
    final List<PrayerSlot> ordered = s.obligatory;
    final int nextIndex =
        ordered.indexWhere((PrayerSlot slot) => slot.id == m.next.id);
    final PrayerSlot? following = nextIndex >= 0 && nextIndex + 1 < ordered.length
        ? ordered[nextIndex + 1]
        : null;

    return NextPrayerHero(
      now: now,
      next: m.next,
      nextIsTomorrow: m.nextIsTomorrow,
      previous: m.current,
      following: following,
      locationLabel: locationLabel,
      use24h: use24h,
      onEarth: true,
      onTap: () => context.push(Routes.prayerTimes),
    );
  }
}

class _LocationNeededCard extends StatelessWidget {
  const _LocationNeededCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      padding: const EdgeInsets.all(Insets.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.location_off_outlined,
              size: 28, color: AppColors.gold,),
          const SizedBox(height: Insets.md),
          Text('Prayer times need your location', style: AppType.titleLg),
          const SizedBox(height: Insets.sm),
          Text(
            message,
            style: AppType.bodySm.copyWith(color: AppColors.mist),
          ),
          const SizedBox(height: Insets.lg),
          PrimaryButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _TahajjudTonightCard extends StatelessWidget {
  const _TahajjudTonightCard({
    required this.window,
    required this.now,
    required this.use24h,
    required this.liveCount,
    required this.onTap,
  });

  final TahajjudWindow window;
  final DateTime now;
  final bool use24h;
  final int liveCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool active = window.isActiveAt(now);
    return NightCard(
      onTap: onTap,
      gradient: PrayerPalette.tahajjud.gradient,
      borderColor: active ? AppColors.gold : AppColors.goldDim,
      padding: const EdgeInsets.all(Insets.xl),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  active ? 'TAHAJJUD IS OPEN NOW' : 'TAHAJJUD TONIGHT',
                  style: AppType.label.copyWith(color: AppColors.goldSoft),
                ),
                const SizedBox(height: Insets.sm),
                Text(
                  '${Fmt.time(window.start, use24h: use24h)} — '
                  '${Fmt.time(window.end, use24h: use24h)}',
                  style: AppType.displaySm.copyWith(color: AppColors.cream),
                ),
                const SizedBox(height: 4),
                Text(
                  active
                      ? 'The last third of the night has begun.'
                      : 'Begins in ${Fmt.countdown(window.timeUntil(now))}',
                  style: AppType.bodySm.copyWith(color: AppColors.mist),
                ),
                if (liveCount > 0) ...<Widget>[
                  const SizedBox(height: Insets.sm),
                  Row(
                    children: <Widget>[
                      Container(
                        height: 7,
                        width: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.emerald,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        liveCount == 1
                            ? '1 person is praying now'
                            : '$liveCount people are praying now',
                        style:
                            AppType.bodySm.copyWith(color: AppColors.goldSoft),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.mistFaint,
          ),
        ],
      ),
    );
  }
}
