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
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/mihrab_arch.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../prayer_times/application/prayer_times_controller.dart';
import '../../prayer_times/domain/prayer.dart';
import '../../streaks/application/streak_controller.dart';
import '../application/tahajjud_controller.dart';
import '../domain/tahajjud_presence.dart';
import 'widgets/map_consent_sheet.dart';

class TahajjudScreen extends ConsumerWidget {
  const TahajjudScreen({super.key});

  Future<void> _startPraying(BuildContext context, WidgetRef ref) async {
    final MapConsent? consent = await showMapConsentSheet(context);
    if (consent == null || !context.mounted) return;

    final bool ok =
        await ref.read(tahajjudControllerProvider.notifier).startPraying(
              appearOnMap: consent.appearOnMap,
              anonymous: consent.anonymous,
            );
    if (!context.mounted) return;
    if (ok) {
      context.showSuccess(
        consent.appearOnMap
            ? 'You are on the map. May your prayer be accepted.'
            : 'Tahajjud recorded privately.',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TahajjudWindow> window =
        ref.watch(tahajjudWindowProvider);
    final DateTime now = ref.watch(clockProvider).value ?? DateTime.now();
    final TahajjudPresence? session = ref.watch(mySessionProvider).value;
    final int liveCount = ref.watch(tahajjudLiveCountProvider).value ?? 0;
    final bool use24h = ref.watch(prayerSettingsProvider).use24hClock;
    final bool prayedTonight =
        ref.watch(todayPrayerDayProvider).value?.tahajjudPrayed ?? false;
    final AsyncValue<void> action = ref.watch(tahajjudControllerProvider);

    ref.listen<AsyncValue<void>>(tahajjudControllerProvider,
        (AsyncValue<void>? previous, AsyncValue<void> next) {
      if (next.hasError && !next.isLoading) context.showError(next.error!);
    });

    return NightScaffold(
      scrollable: true,
      ornamentHeight: 320,
      padding: const EdgeInsets.symmetric(horizontal: Insets.page),
      child: window.when(
        loading: () => const SizedBox(
          height: 420,
          child: LoadingView(message: 'Finding the last third of the night…'),
        ),
        error: (Object error, StackTrace stack) => SizedBox(
          height: 420,
          child: ErrorView(
            message: 'Tahajjud times need your location.',
            onRetry: () => ref.invalidate(placeProvider),
          ),
        ),
        data: (TahajjudWindow w) {
          final bool isOpen = w.isActiveAt(now);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: Insets.lg),
              Text('Tahajjud', style: AppType.displayLg),
              const SizedBox(height: 4),
              Text(
                'The night prayer, in the last third of the night.',
                style: AppType.bodySm.copyWith(color: AppColors.mist),
              ),
              const SizedBox(height: Insets.xl),
              _WindowCard(window: w, now: now, use24h: use24h, isOpen: isOpen),
              const SizedBox(height: Insets.xl),
              if (session != null)
                _ActiveSessionCard(
                  session: session,
                  busy: action.isLoading,
                  onEnd: () async {
                    final bool ok = await ref
                        .read(tahajjudControllerProvider.notifier)
                        .stopAppearing();
                    if (ok && context.mounted) {
                      context.showMessage('You have left the map.');
                    }
                  },
                )
              else
                PrimaryButton(
                  label: prayedTonight
                      ? 'I am praying Tahajjud again'
                      : 'I am Praying Tahajjud',
                  icon: Icons.self_improvement_rounded,
                  busy: action.isLoading,
                  onPressed: () => _startPraying(context, ref),
                ),
              if (!isOpen && session == null) ...<Widget>[
                const SizedBox(height: Insets.md),
                Text(
                  'The window has not opened yet — you can still record a '
                  'voluntary night prayer.',
                  textAlign: TextAlign.center,
                  style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                ),
              ],
              const SizedBox(height: Insets.xxl),
              const SectionHeader(label: 'Tonight'),
              _LiveMapCard(
                liveCount: liveCount,
                onTap: () => context.push(Routes.tahajjudMap),
              ),
              const SizedBox(height: Insets.md),
              NightCard(
                onTap: () => context.push(Routes.stories),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.menu_book_rounded,
                        color: AppColors.gold, size: 22,),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Tahajjud Stories', style: AppType.titleMd),
                          const SizedBox(height: 2),
                          Text(
                            'What others felt after praying tonight.',
                            style: AppType.bodySm
                                .copyWith(color: AppColors.mistFaint),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.mistFaint,),
                  ],
                ),
              ),
              const SizedBox(height: Insets.xl),
              _AboutTahajjud(nights: ref.watch(userStatsProvider).totalTahajjud),
            ],
          );
        },
      ),
    );
  }
}

class _WindowCard extends StatelessWidget {
  const _WindowCard({
    required this.window,
    required this.now,
    required this.use24h,
    required this.isOpen,
  });

  final TahajjudWindow window;
  final DateTime now;
  final bool use24h;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: PrayerPalette.tahajjud.gradient,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: isOpen ? AppColors.gold : AppColors.goldDim),
      ),
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: 30),
              child: MihrabGlow(color: AppColors.goldSoft, opacity: 0.18),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Insets.xl),
            child: Column(
              children: <Widget>[
                Text(
                  isOpen ? 'OPEN NOW' : 'OPENS TONIGHT',
                  style: AppType.label.copyWith(color: AppColors.goldSoft),
                ),
                const SizedBox(height: Insets.lg),
                Text(
                  isOpen
                      ? Fmt.countdown(window.remaining(now))
                      : Fmt.countdown(window.timeUntil(now)),
                  style: AppType.clock.copyWith(
                    color: AppColors.cream,
                    fontSize: 46,
                  ),
                ),
                Text(
                  isOpen ? 'remaining until Fajr' : 'until the window opens',
                  style: AppType.bodySm.copyWith(color: AppColors.mist),
                ),
                const SizedBox(height: Insets.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    _Endpoint(
                      label: 'Last third begins',
                      value: Fmt.time(window.start, use24h: use24h),
                    ),
                    Container(
                      height: 32,
                      width: 1,
                      color: AppColors.goldDim.withValues(alpha: 0.5),
                    ),
                    _Endpoint(
                      label: 'Fajr',
                      value: Fmt.time(window.end, use24h: use24h),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppType.label.copyWith(color: AppColors.mistFaint),
          ),
          const SizedBox(height: 4),
          Text(value, style: AppType.numeral.copyWith(color: AppColors.cream)),
        ],
      );
}

class _ActiveSessionCard extends StatelessWidget {
  const _ActiveSessionCard({
    required this.session,
    required this.onEnd,
    required this.busy,
  });

  final TahajjudPresence session;
  final VoidCallback onEnd;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      borderColor: AppColors.emerald,
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                height: 9,
                width: 9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  'You are on the map',
                  style: AppType.titleMd.copyWith(color: AppColors.cream),
                ),
              ),
              Text(
                Fmt.countdown(session.elapsed),
                style: AppType.numeral.copyWith(color: AppColors.mist),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Showing as "${session.displayName}" in a ~5 km area. Disappears '
              'automatically at ${Fmt.time(session.expiresAt)}.',
              style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
            ),
          ),
          const SizedBox(height: Insets.lg),
          GhostButton(
            label: 'End session and leave the map',
            icon: Icons.logout_rounded,
            onPressed: busy ? null : onEnd,
          ),
        ],
      ),
    );
  }
}

class _LiveMapCard extends StatelessWidget {
  const _LiveMapCard({required this.liveCount, required this.onTap});

  final int liveCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          const Icon(Icons.public_rounded, color: AppColors.gold, size: 22),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Live map', style: AppType.titleMd),
                const SizedBox(height: 2),
                Text(
                  liveCount == 0
                      ? 'Nobody is praying right now.'
                      : liveCount == 1
                          ? '1 person is praying right now.'
                          : '$liveCount people are praying right now.',
                  style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.mistFaint),
        ],
      ),
    );
  }
}

class _AboutTahajjud extends StatelessWidget {
  const _AboutTahajjud({required this.nights});

  final int nights;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('About this window', style: AppType.titleMd),
          const SizedBox(height: Insets.sm),
          Text(
            'Layla divides the night — from Maghrib to Fajr — into three parts '
            'and shows the last one. Tahajjud is voluntary, so it is recorded '
            'without the photo step and never affects your five-prayer streak.',
            style: AppType.bodySm.copyWith(color: AppColors.mist, height: 1.5),
          ),
          const SizedBox(height: Insets.lg),
          Row(
            children: <Widget>[
              const Icon(Icons.nights_stay_outlined,
                  size: 18, color: AppColors.goldDim,),
              const SizedBox(width: Insets.sm),
              Text(
                nights == 1
                    ? '1 night recorded'
                    : '$nights nights recorded',
                style: AppType.bodySm.copyWith(color: AppColors.mist),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
