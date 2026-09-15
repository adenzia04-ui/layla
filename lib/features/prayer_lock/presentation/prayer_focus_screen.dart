import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/mihrab_arch.dart';
import '../../../core/widgets/ornament_backdrop.dart';
import '../../prayer_times/application/prayer_times_controller.dart';
import '../../premium/application/premium_store.dart';
import '../application/prayer_lock_controller.dart';
import '../domain/prayer_session.dart';
import 'scan_flow.dart';

/// The 30-minute prayer window, full screen.
///
/// This is the honest core of the "lock": no bottom navigation, no system back,
/// screen kept awake, and it re-opens every time Noor is reopened while the
/// prayer is unconfirmed. What it cannot do is stop the user opening another
/// app — see `docs/PRAYER_LOCK_LIMITATIONS.md`.
class PrayerFocusScreen extends ConsumerStatefulWidget {
  const PrayerFocusScreen({super.key, required this.prayerKey});

  final String prayerKey;

  @override
  ConsumerState<PrayerFocusScreen> createState() => _PrayerFocusScreenState();
}

class _PrayerFocusScreenState extends ConsumerState<PrayerFocusScreen> {
  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final PrayerSession? session = ref.read(activeSessionProvider);
      if (session != null) {
        ref.read(prayerLockControllerProvider.notifier).engageLock(session);
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PrayerSession? session = ref.watch(activeSessionProvider);
    final DateTime now = ref.watch(clockProvider).valueOrNull ?? DateTime.now();
    final bool use24h = ref.watch(prayerSettingsProvider).use24hClock;

    // The window closed (or the prayer was confirmed) while we were here.
    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(Routes.home);
      });
      return const Scaffold(backgroundColor: AppColors.midnight);
    }

    final PrayerPalette palette = session.prayer.palette;

    return PopScope(
      // System back is disabled: leaving is a deliberate choice made with the
      // button below, and impossible at all once Step 1 has been pressed.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.midnight,
        body: Container(
          decoration: BoxDecoration(gradient: palette.gradient),
          child: Stack(
            children: <Widget>[
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: OrnamentBackdrop(height: 300, opacity: 0.15),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(top: 120),
                  child: MihrabGlow(color: palette.onSurface, opacity: 0.18),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.xxl,
                    vertical: Insets.lg,
                  ),
                  child: Column(
                    children: <Widget>[
                      Text(
                        'PRAYER FOCUS',
                        style: AppType.label.copyWith(color: palette.onSurface),
                      ),
                      const Spacer(),
                      Icon(
                        session.prayer.icon,
                        size: 30,
                        color: palette.onSurface,
                      ),
                      const SizedBox(height: Insets.md),
                      Text(
                        session.prayer.label,
                        style: AppType.displayXl.copyWith(
                          color: palette.onSurface,
                        ),
                      ),
                      Text(
                        'began at '
                        '${Fmt.time(session.startedAt, use24h: use24h)}',
                        style: AppType.bodySm.copyWith(
                          color: palette.onSurface.withValues(alpha: 0.75),
                        ),
                      ),
                      const SizedBox(height: Insets.xxl),
                      // Once the 30 minutes elapse the session does not end —
                      // it goes overdue, and a frozen 00:00 would read as a
                      // bug. Swap the countdown for the reason apps are still
                      // paused.
                      if (session.isOverdueAt(now)) ...<Widget>[
                        Icon(
                          Icons.lock_clock_rounded,
                          size: 44,
                          color: palette.onSurface,
                        ),
                        const SizedBox(height: Insets.md),
                        Text(
                          'Your apps stay paused',
                          style: AppType.displaySm.copyWith(
                            color: palette.onSurface,
                          ),
                        ),
                        Text(
                          'until this prayer is confirmed',
                          style: AppType.bodySm.copyWith(
                            color: palette.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                      ] else ...<Widget>[
                        Text(
                          Fmt.mmss(session.remaining(now)),
                          style: AppType.clock.copyWith(
                            fontSize: 62,
                            color: palette.onSurface,
                          ),
                        ),
                        Text(
                          'left in this window',
                          style: AppType.bodySm.copyWith(
                            color: palette.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                      const SizedBox(height: Insets.xl),
                      ClipRRect(
                        borderRadius: Radii.chip,
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          value: session.isOverdueAt(now)
                              ? null
                              : session.progress(now),
                          backgroundColor: palette.onSurface.withValues(
                            alpha: 0.18,
                          ),
                          color: palette.onSurface,
                        ),
                      ),
                      const Spacer(),
                      if (session.awaitingProof)
                        _AwaitingProofNotice(palette: palette),
                      const SizedBox(height: Insets.lg),
                      // Three ways out, and every one of them lifts the
                      // shield.
                      //
                      // It used to be two-and-a-half: confirm with a photo,
                      // mark it missed, or step back to Layla Pro with the apps
                      // still paused. That third one was the problem — someone
                      // driving, at work, or away from a mat had no honest
                      // move. Their choices were to lie and press "I have
                      // prayed", or to record a miss that had not happened and
                      // break a streak. An app that makes honesty the
                      // expensive option teaches people to stop being honest
                      // with it.
                      PrimaryButton(
                        label: !ref.watch(isProProvider)
                            ? 'I have prayed'
                            : session.awaitingProof
                            ? 'Scan your prayer mat'
                            : 'I have prayed',
                        icon: session.awaitingProof && ref.watch(isProProvider)
                            ? Icons.center_focus_strong_rounded
                            : Icons.check_rounded,
                        // The camera opens over this screen; once the mat is
                        // scanned, Home.
                        onPressed: ref.watch(isProProvider)
                            ? () async {
                                final bool ok = await confirmWithScan(
                                  context,
                                  ref,
                                  session,
                                );
                                if (ok && context.mounted) {
                                  context.go(Routes.home);
                                }
                              }
                            : () async {
                                final bool ok = await ref
                                    .read(prayerLockControllerProvider.notifier)
                                    .confirmWithoutProof(session);
                                if (ok && context.mounted) {
                                  context
                                    ..showSuccess(
                                      '${session.prayer.label} confirmed. '
                                      'May it be accepted.',
                                    )
                                    ..go(Routes.home);
                                }
                              },
                      ),
                      const SizedBox(height: Insets.sm),

                      // Step 1 is a commitment: once "I am praying now" has
                      // been pressed, the photo is the only way on, and this
                      // option is not offered.
                      if (!session.awaitingProof) ...<Widget>[
                        SizedBox(
                          height: 46,
                          child: TextButton(
                            onPressed: () async {
                              final bool ok = await ref
                                  .read(prayerLockControllerProvider.notifier)
                                  .deferUntilHome(session);
                              if (!context.mounted) return;
                              if (ok) {
                                context.go(Routes.home);
                              } else {
                                context.showMessage(
                                  'That could not be saved. Your apps stay '
                                  'paused until it is.',
                                );
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: palette.onSurface.withValues(
                                alpha: 0.85,
                              ),
                            ),
                            child: const Text('I will pray when I am home'),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final bool confirmed = await _confirmMissed(
                              context,
                            );
                            if (!confirmed || !context.mounted) return;
                            final bool ok = await ref
                                .read(prayerLockControllerProvider.notifier)
                                .markMissed(session);
                            if (!context.mounted) return;
                            if (ok) {
                              context.go(Routes.home);
                            } else {
                              context.showMessage(
                                'That could not be saved. Your apps stay '
                                'paused until it is.',
                              );
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.rose,
                          ),
                          child: const Text('I did not pray this one'),
                        ),
                      ] else
                        SizedBox(
                          height: 46,
                          child: Center(
                            child: Text(
                              'This prayer stays unconfirmed until the photo '
                              'is saved.',
                              textAlign: TextAlign.center,
                              style: AppType.bodySm.copyWith(
                                color: palette.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AwaitingProofNotice extends StatelessWidget {
  const _AwaitingProofNotice({required this.palette});

  final PrayerPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.pending_actions_rounded,
            color: AppColors.amber,
            size: 20,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              'Step 1 done. One step left: scan your prayer mat.',
              style: AppType.bodySm.copyWith(color: AppColors.cream),
            ),
          ),
        ],
      ),
    );
  }
}

/// Marking a prayer missed breaks the streak and cannot be undone, so it asks
/// once. The wording states the cost plainly rather than softening it — a user
/// who taps this by accident loses real progress.
Future<bool> _confirmMissed(BuildContext context) async {
  final bool? answer = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      backgroundColor: AppColors.navyElevated,
      title: Text('Mark this prayer as missed?', style: AppType.titleLg),
      content: Text(
        'It will not count toward today, and your streak will end. Your apps '
        'will be unblocked.',
        style: AppType.bodySm.copyWith(color: AppColors.mist),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: AppColors.rose),
          child: const Text('Yes, I missed it'),
        ),
      ],
    ),
  );
  return answer ?? false;
}
