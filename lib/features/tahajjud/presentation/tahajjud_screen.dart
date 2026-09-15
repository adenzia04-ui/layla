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

    final bool ok = await ref
        .read(tahajjudControllerProvider.notifier)
        .startPraying(
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
    final AsyncValue<TahajjudWindow> window = ref.watch(tahajjudWindowProvider);
    final DateTime now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final TahajjudPresence? session = ref.watch(mySessionProvider).valueOrNull;
    final int liveCount = ref.watch(tahajjudLiveCountProvider).valueOrNull ?? 0;
    final bool use24h = ref.watch(prayerSettingsProvider).use24hClock;
    final bool prayedTonight =
        ref.watch(todayPrayerDayProvider).valueOrNull?.tahajjudPrayed ?? false;
    final AsyncValue<void> action = ref.watch(tahajjudControllerProvider);

    ref.listen<AsyncValue<void>>(tahajjudControllerProvider, (
      AsyncValue<void>? previous,
      AsyncValue<void> next,
    ) {
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
                    // People with a heart between them: what others felt.
                    const Icon(
                      Icons.diversity_1_rounded,
                      color: AppColors.gold,
                      size: 22,
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Tahajjud Stories', style: AppType.titleMd),
                          const SizedBox(height: 2),
                          Text(
                            'What others felt after praying tonight.',
                            style: AppType.bodySm.copyWith(
                              color: AppColors.mistFaint,
                            ),
                          ),
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
              const SizedBox(height: Insets.xl),
              _AboutTahajjud(
                nights: ref.watch(userStatsProvider).totalTahajjud,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WindowCard extends StatefulWidget {
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
  State<_WindowCard> createState() => _WindowCardState();
}

/// The night as an arc from Maghrib to Fajr, the last third of it gold,
/// and a crescent where the night is now.
///
/// Was a box with a big number in it. The number stays — how long until
/// the window, or how long is left in it — but it now sits under the shape
/// of the night itself, so "the last third" is something you can see.
class _WindowCardState extends State<_WindowCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TahajjudWindow w = widget.window;
    final DateTime now = widget.now;
    // The window is the last third, so the night began two windows earlier.
    final Duration third = w.end.difference(w.start);
    final DateTime maghrib = w.start.subtract(third * 2);
    final Duration nightLength = w.end.difference(maghrib);
    final double at = nightLength.inSeconds <= 0
        ? 0
        : (now.difference(maghrib).inSeconds / nightLength.inSeconds).clamp(
            0.0,
            1.0,
          );

    // Until the window: never "now". After Fajr the next window is tonight's,
    // a day on, and the count says so instead of reading zero.
    Duration until = w.timeUntil(now);
    if (until.isNegative) until += const Duration(days: 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              widget.isOpen ? Icons.nightlight_round : Icons.bedtime_outlined,
              size: 14,
              color: AppColors.gold,
            ),
            const SizedBox(width: Insets.sm),
            Text(
              widget.isOpen
                  ? 'THE LAST THIRD IS OPEN'
                  : 'THE LAST THIRD TONIGHT',
              style: AppType.label.copyWith(color: AppColors.gold),
            ),
          ],
        ),
        const SizedBox(height: Insets.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              widget.isOpen
                  ? Fmt.countdown(w.remaining(now))
                  : Fmt.countdown(until),
              style: AppType.clock.copyWith(
                color: AppColors.cream,
                fontSize: 44,
              ),
            ),
            const SizedBox(width: Insets.md),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                widget.isOpen ? 'left until Fajr' : 'until it opens',
                style: AppType.bodySm.copyWith(color: AppColors.mist),
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.sm),
        SizedBox(
          height: 110,
          child: AnimatedBuilder(
            animation: _breath,
            builder: (BuildContext context, _) => CustomPaint(
              size: Size.infinite,
              painter: _NightArcPainter(
                at: at,
                open: widget.isOpen,
                breath: Curves.easeInOut.transform(_breath.value),
              ),
            ),
          ),
        ),
        Row(
          children: <Widget>[
            _Endpoint(
              label: 'Maghrib',
              value: Fmt.time(maghrib, use24h: widget.use24h),
              align: CrossAxisAlignment.start,
            ),
            const Spacer(),
            _Endpoint(
              label: 'Last third',
              value: Fmt.time(w.start, use24h: widget.use24h),
              align: CrossAxisAlignment.center,
              gold: true,
            ),
            const Spacer(),
            _Endpoint(
              label: 'Fajr',
              value: Fmt.time(w.end, use24h: widget.use24h),
              align: CrossAxisAlignment.end,
            ),
          ],
        ),
      ],
    );
  }
}

class _NightArcPainter extends CustomPainter {
  const _NightArcPainter({
    required this.at,
    required this.open,
    required this.breath,
  });

  /// 0 at Maghrib, 1 at Fajr.
  final double at;
  final bool open;
  final double breath;

  Offset _p(double t, Size size) {
    final Offset p0 = Offset(size.width * 0.04, size.height - 14);
    final Offset p1 = Offset(size.width / 2, -size.height * 0.5);
    final Offset p2 = Offset(size.width * 0.96, size.height - 14);
    final double u = 1 - t;
    return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t);
  }

  Path _arc(Size size, double from, double to) {
    final Path path = Path();
    const int n = 48;
    for (int i = 0; i <= n; i++) {
      final Offset p = _p(from + (to - from) * i / n, size);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // The whole night, faint.
    canvas.drawPath(
      _arc(size, 0, 1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.navyLine,
    );
    // The last third, gold — glowing while it is open.
    canvas.drawPath(
      _arc(size, 2 / 3, 1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = AppColors.gold.withValues(
          alpha: open ? 0.5 + breath * 0.3 : 0.55,
        ),
    );
    if (open) {
      canvas.drawPath(
        _arc(size, 2 / 3, 1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
          ..color = AppColors.gold.withValues(alpha: 0.18 + breath * 0.12),
      );
    }
    // Ticks at the thirds.
    for (final double t in <double>[1 / 3, 2 / 3]) {
      final Offset c = _p(t, size);
      canvas.drawCircle(c, 2.5, Paint()..color = AppColors.mistFaint);
    }
    // Stars along the top of the night.
    final Paint star = Paint()..color = AppColors.cream.withValues(alpha: 0.35);
    for (final (double x, double y, double r)
        in const <(double, double, double)>[
          (0.18, 0.12, 1.2),
          (0.32, 0.04, 0.9),
          (0.57, 0.02, 1.3),
          (0.71, 0.1, 0.9),
          (0.86, 0.22, 1.1),
          (0.45, 0.16, 0.7),
        ]) {
      canvas.drawCircle(Offset(x * size.width, y * size.height), r, star);
    }
    // The crescent, where the night is now.
    final Offset c = _p(at, size);
    canvas.drawCircle(
      c,
      13 + breath * 3,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            AppColors.goldSoft.withValues(alpha: 0.45),
            AppColors.goldSoft.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: 16)),
    );
    // A crescent is one disc with another taken out of it — a real
    // difference, not an even-odd fill, which left a sliver wherever the
    // second disc reached past the first and made the moon a lumpy thing.
    final Path moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: 7)),
      Path()..addOval(
        Rect.fromCircle(center: c + const Offset(3, -1.2), radius: 6),
      ),
    );
    canvas.drawPath(moon, Paint()..color = AppColors.goldSoft);
  }

  @override
  bool shouldRepaint(_NightArcPainter old) =>
      old.at != at || old.open != open || old.breath != breath;
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.label,
    required this.value,
    required this.align,
    this.gold = false,
  });

  final String label;
  final String value;
  final CrossAxisAlignment align;
  final bool gold;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: align,
    children: <Widget>[
      Text(
        label.toUpperCase(),
        style: AppType.label.copyWith(
          color: gold ? AppColors.gold : AppColors.mistFaint,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        value,
        style: AppType.numeral.copyWith(
          color: gold ? AppColors.goldSoft : AppColors.cream,
        ),
      ),
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
            'Layla Pro divides the night — from Maghrib to Fajr — into three parts '
            'and shows the last one. Tahajjud is voluntary, so it is recorded '
            'without the photo step and never affects your five-prayer streak.',
            style: AppType.bodySm.copyWith(color: AppColors.mist, height: 1.5),
          ),
          const SizedBox(height: Insets.lg),
          Row(
            children: <Widget>[
              const Icon(
                Icons.nights_stay_outlined,
                size: 18,
                color: AppColors.goldDim,
              ),
              const SizedBox(width: Insets.sm),
              Text(
                nights == 1 ? '1 night recorded' : '$nights nights recorded',
                style: AppType.bodySm.copyWith(color: AppColors.mist),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
