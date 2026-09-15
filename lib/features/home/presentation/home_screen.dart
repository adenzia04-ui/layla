import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../shell/app_shell.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../dua/presentation/dua_test_screen.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/avatar_circle.dart';
import '../../../core/widgets/noor_flame.dart';
import '../../../core/widgets/noor_globe.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../prayer_times/application/prayer_times_controller.dart';
import '../../prayer_times/domain/prayer.dart';
import '../../profile/domain/avatar.dart';
import '../../cycle/presentation/cycle_pause_control.dart';
import '../../streaks/application/streak_controller.dart';
import '../../streaks/domain/prayer_day.dart';
import '../../tahajjud/application/tahajjud_controller.dart';
import '../../friends/presentation/widgets/home_lines.dart';
import 'widgets/feature_rail.dart';
import 'widgets/next_prayer_hero.dart';
import 'widgets/prayer_arc.dart';
import 'widgets/ramadan_card.dart';
import 'widgets/today_progress_card.dart';
import '../../prayer_lock/application/prayer_lock_controller.dart';
import '../../prayer_lock/domain/prayer_session.dart';
import 'widgets/prayer_choice_card.dart';
import '../../streaks/data/prayer_day_repository.dart';
import '../../../core/widgets/app_snackbar.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the OS alarm queue in step with the computed schedule.

    final AppUser? user = ref.watch(appUserProvider).valueOrNull;
    final AsyncValue<NoorPlace> place = ref.watch(placeProvider);
    final PrayerSession? session = ref.watch(activeSessionProvider);
    final AsyncValue<PrayerSchedule> schedule = ref.watch(
      prayerScheduleProvider,
    );
    final AsyncValue<PrayerMoment> moment = ref.watch(prayerMomentProvider);
    final DateTime now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final PrayerDay day =
        ref.watch(todayPrayerDayProvider).valueOrNull ??
        PrayerDay.empty(Fmt.dayId(now));
    // Today as this screen should draw it. The same day for everybody except
    // someone whose prayer pause is on, and for her the day the catch-up is
    // about to write — see `cycleDayFor`. Taken once so that everything the
    // progress card is handed comes from a single answer.
    final PrayerDay shownDay = cycleDayFor(ref, day);
    final bool use24h = ref.watch(prayerSettingsProvider).use24hClock;
    final int liveTahajjud =
        ref.watch(tahajjudLiveCountProvider).valueOrNull ?? 0;

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
                  prayer: moment.valueOrNull?.current?.id,
                  latitude: place.valueOrNull?.lat,
                  longitude: place.valueOrNull?.lng,
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
                  _Greeting(user: user, now: now, place: place.valueOrNull),
                  const SizedBox(height: Insets.xl),
                  _HeroSection(
                    schedule: schedule,
                    moment: moment,
                    now: now,
                    use24h: use24h,
                    locationLabel: place.valueOrNull?.label ?? 'Locating…',
                    onRetryLocation: () => ref.invalidate(placeProvider),
                  ),
                  const SizedBox(height: Insets.lg),
                  if (schedule.hasValue)
                    // The same panel as the countdown above: a wash of night that
                    // deepens toward the bottom, so the arc reads as a card over the
                    // Earth rather than something drawn on its edge.
                    Container(
                      clipBehavior: Clip.antiAlias,
                      padding: const EdgeInsets.fromLTRB(
                        Insets.md,
                        Insets.lg,
                        Insets.md,
                        Insets.sm,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            AppColors.midnight.withValues(alpha: 0.12),
                            AppColors.midnight.withValues(alpha: 0.46),
                            AppColors.midnight.withValues(alpha: 0.78),
                          ],
                          stops: const <double>[0, 0.45, 1],
                        ),
                        borderRadius: BorderRadius.circular(Radii.xl),
                      ),
                      child: PrayerArc(
                        schedule: schedule.requireValue,
                        now: now,
                        // The same day the card below it draws. A prayer
                        // marked missed earlier that morning would otherwise
                        // keep its cross up here while the card underneath
                        // said nothing was missed.
                        day: shownDay,
                        use24h: use24h,
                        onTapPrayer: (PrayerId id) => context.push(
                          id == PrayerId.tahajjud
                              ? Routes.tahajjud
                              : Routes.prayerTimes,
                        ),
                      ),
                    ),
                  const SizedBox(height: Insets.xl),
                  TodayProgressCard(
                    // Drawn as the pause will leave it rather than as the day
                    // document currently reads, so the summary and the panel
                    // below it cannot contradict each other while the catch-up
                    // write is still in the air. Untouched for everybody else.
                    day: shownDay,
                    currentStreak: ref.watch(userStatsProvider).streakOn(now),
                    // Nothing to reopen on a day the pause covers. A prayer
                    // marked missed earlier that morning, or one put off with
                    // "when I am home", would otherwise leave a bead drawn as
                    // a quiet dash but still offering to put a prayer back —
                    // and there is no prayer to put back on a day none was
                    // owed. The repository refuses it too; this is so the
                    // offer is never made.
                    reopenable: shownDay.excused
                        ? const <PrayerId>{}
                        : _reopenable(ref, shownDay, schedule.valueOrNull, now),
                    onReopen: (PrayerId id) =>
                        _reopenPrayer(context, ref, id, shownDay, now),
                    // The open prayer is answered inside this card, under the
                    // streak — the same place that already says what has and
                    // has not been prayed today.
                    //
                    // For a sister the same slot also carries the prayer
                    // pause: a quiet line under the answers normally, and the
                    // pause itself in their place while it is on. For everyone
                    // else `buildCycleChoices` hands the choices straight back
                    // untouched, so nothing of it exists in their tree.
                    choices: buildCycleChoices(
                      ref,
                      now: now,
                      choices: session == null
                          ? null
                          : PrayerChoiceCard(session: session),
                    ),
                  ),
                  // Under Today's Progress, each only when it has something
                  // to say: Ramadan's two switches, Eid's one tap, and the
                  // line for what friends have sent.
                  const RamadanCard(),
                  const EidGreetingLine(),
                  const InboxLine(),
                  const SizedBox(height: Insets.xl),
                  const SectionHeader(label: 'Main features'),
                  FeatureRail(
                    items: <FeatureItem>[
                      FeatureItem(
                        label: 'Prayer Times',
                        icon: Icons.access_time_rounded,
                        // Qiyam and sujud rather than a clock face. The palette
                        // is already Layla Pro's — gold standing, grey prostrate —
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
                        onTap: () => context.push(Routes.qibla),
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
                        label: 'Prayer Streak',
                        icon: Icons.local_fire_department_rounded,
                        accent: AppColors.ember,
                        iconWidget: const NoorFlame(size: 26, glow: false),
                        onTap: () => context.push(Routes.streak),
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
                        label: 'Mood',
                        icon: Icons.favorite_outline_rounded,
                        accent: PrayerPalette.maghrib.end,
                        onTap: () => context.push(Routes.mood),
                      ),
                      FeatureItem(
                        label: 'Names of Allah',
                        icon: Icons.auto_awesome_rounded,
                        accent: AppColors.goldSoft,
                        onTap: () => context.push(Routes.soulNames),
                      ),
                      FeatureItem(
                        label: 'Duas',
                        icon: Icons.import_contacts_rounded,
                        accent: AppColors.gold,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) =>
                                const DuaTestScreen(),
                          ),
                        ),
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

/// Which prayers can be answered again.
///
/// Two quite different states, one gesture: a prayer marked missed, and one
/// put off with "I will pray when I am home". Both hide the choices, so both
/// need a way back — and from the outside they are the same complaint, "the
/// buttons are gone".
///
/// A prayer whose time has not come yet is excluded: there is nothing to
/// answer, and a tap that silently does nothing is worse than no tap.
Set<PrayerId> _reopenable(
  WidgetRef ref,
  PrayerDay day,
  PrayerSchedule? schedule,
  DateTime now,
) {
  if (schedule == null) return const <PrayerId>{};
  final Set<String> dismissed = ref.watch(dismissedSessionsProvider);
  final String today = Fmt.dayId(now);

  return <PrayerId>{
    for (final PrayerId id in PrayerId.obligatory)
      if (!now.isBefore(schedule.slotFor(id).start))
        if (day.recordFor(id).status == PrayerStatus.missed ||
            dismissed.contains('$today|${id.key}'))
          id,
  };
}

/// Puts a prayer marked missed back to pending, after asking.
///
/// Confirmed first because it is not free: reopening does not restore the
/// streak that marking a miss zeroed, and saying so up front is better than
/// someone discovering it afterwards.
Future<void> _reopenPrayer(
  BuildContext context,
  WidgetRef ref,
  PrayerId prayer,
  PrayerDay day,
  DateTime now,
) async {
  // Only a recorded miss touches Firestore. One that was merely put off is
  // still pending there — all that hid it was a dismissal held in memory, so
  // bringing it back is a local matter and needs no dialog at all.
  if (day.recordFor(prayer).status != PrayerStatus.missed) {
    ref
        .read(dismissedSessionsProvider.notifier)
        .clear('${Fmt.dayId(now)}|${prayer.key}');
    return;
  }

  final bool? yes = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      backgroundColor: AppColors.navyElevated,
      title: Text('Reopen ${prayer.label}?', style: AppType.titleMd),
      content: Text(
        'It goes back to unprayed, so you can still confirm it today. The '
        'streak it broke does not come back.',
        style: AppType.bodySm.copyWith(color: AppColors.mist),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Leave it'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.gold),
          child: const Text('Reopen'),
        ),
      ],
    ),
  );
  if (yes != true || !context.mounted) return;

  try {
    await ref
        .read(prayerDayRepositoryProvider)
        .reopen(prayer: prayer, dateId: Fmt.dayId(now));
  } on Object catch (e) {
    debugPrint('Layla Pro: could not reopen ${prayer.key} ($e)');
    if (context.mounted) {
      context.showMessage('That could not be saved. Try again in a moment.');
    }
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
        // Their own picture when they have set one, the plain icon when they
        // have not. Initials are deliberately not the fallback here: this is a
        // toolbar button first, and every other one on the dashboard is an
        // icon — a lone pair of letters would read as a notification badge.
        if (Avatar.isUsable(user?.photo))
          AvatarCircle(
            initials: user?.initials ?? '?',
            photo: user?.photo,
            size: 48,
            onTap: () => context.push(Routes.profile),
            // The same name the plain-icon branch below gives it: this button
            // opens the profile whether or not a picture has been set, and
            // a screen reader should not hear it renamed by that.
            semanticLabel: 'Profile',
          )
        else
          CircleIconButton(
            icon: Icons.person_outline_rounded,
            tooltip: 'Profile',
            onPressed: () => context.push(Routes.profile),
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
    final int nextIndex = ordered.indexWhere(
      (PrayerSlot slot) => slot.id == m.next.id,
    );
    final PrayerSlot? following =
        nextIndex >= 0 && nextIndex + 1 < ordered.length
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
          const Icon(
            Icons.location_off_outlined,
            size: 28,
            color: AppColors.gold,
          ),
          const SizedBox(height: Insets.md),
          Text('Prayer times need your location', style: AppType.titleLg),
          const SizedBox(height: Insets.sm),
          Text(message, style: AppType.bodySm.copyWith(color: AppColors.mist)),
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
    // No gold rule around it. The card is lit from within instead: a soft
    // moonlight pooling in one corner, brighter while the window is open,
    // and a crescent standing in it.
    return NightCard(
      onTap: onTap,
      gradient: PrayerPalette.tahajjud.gradient,
      borderColor: AppColors.navyLine.withValues(alpha: 0.35),
      padding: EdgeInsets.zero,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _Moonlight(active: active)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Insets.xl),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        active ? 'TAHAJJUD IS OPEN NOW' : 'TAHAJJUD TONIGHT',
                        style: AppType.label.copyWith(
                          color: AppColors.goldSoft,
                        ),
                      ),
                      const SizedBox(height: Insets.sm),
                      Text(
                        '${Fmt.time(window.start, use24h: use24h)} — '
                        '${Fmt.time(window.end, use24h: use24h)}',
                        style: AppType.displaySm.copyWith(
                          color: AppColors.cream,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        active
                            ? 'The last third of the night has begun.'
                            : window.end.isBefore(now)
                            ? 'Tonight\'s window has passed. The next opens '
                                  'after Maghrib.'
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
                              style: AppType.bodySm.copyWith(
                                color: AppColors.goldSoft,
                              ),
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
          ),
        ],
      ),
    );
  }
}

/// Moonlight in the corner of the Tahajjud card, and the moon itself.
class _Moonlight extends CustomPainter {
  const _Moonlight({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset moon = Offset(size.width - 44, 34);
    canvas.drawCircle(
      moon,
      size.width * 0.55,
      Paint()
        ..shader =
            RadialGradient(
              colors: <Color>[
                AppColors.goldSoft.withValues(alpha: active ? 0.28 : 0.16),
                AppColors.pulse.withValues(alpha: active ? 0.10 : 0.05),
                Colors.transparent,
              ],
              stops: const <double>[0, 0.45, 1],
            ).createShader(
              Rect.fromCircle(center: moon, radius: size.width * 0.55),
            ),
    );
    final Paint star = Paint()..color = AppColors.cream.withValues(alpha: 0.5);
    for (final (double x, double y, double r)
        in const <(double, double, double)>[
          (0.62, 0.22, 1.1),
          (0.74, 0.62, 0.8),
          (0.88, 0.78, 1.0),
          (0.55, 0.7, 0.7),
        ]) {
      canvas.drawCircle(Offset(size.width * x, size.height * y), r, star);
    }
    final Path crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: moon, radius: 11)),
      Path()..addOval(
        Rect.fromCircle(center: moon + const Offset(4.6, -2), radius: 9.4),
      ),
    );
    canvas.drawPath(
      crescent,
      Paint()
        ..color = AppColors.goldSoft.withValues(alpha: active ? 0.95 : 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 3),
    );
  }

  @override
  bool shouldRepaint(_Moonlight old) => old.active != active;
}

/// One chevron. Tap it and Settings and Profile unfold beneath; tap again
/// and they fold away. Two buttons in the corner at all times was two
/// things to look at on a screen that should open on the Earth.
