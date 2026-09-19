import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/platform_features.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../premium/application/premium_store.dart';
import '../../../prayer_lock/application/prayer_lock_controller.dart';
import '../../../prayer_lock/application/prayer_lock_sync.dart';
import '../../../prayer_lock/domain/prayer_session.dart';
import '../../../prayer_lock/presentation/scan_flow.dart';
import '../../../prayer_lock/presentation/widgets/mat_scan_offer.dart';

/// One line explaining what an answer costs.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 13, color: AppColors.mistFaint),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: AppType.bodySm.copyWith(
              fontSize: 11,
              color: AppColors.mistFaint,
            ),
          ),
        ),
      ],
    ),
  );
}

/// The open prayer, answered from the home screen.
///
/// This is where the focus screen's choices moved to. A prayer window used to
/// take the whole app over the moment it opened — mid-message, mid-anything —
/// and the only way out was to answer it. Pausing the *other* apps is the
/// feature; commandeering Layla Pro was collateral.
///
/// So the same three answers sit here instead, in the first thing anyone sees,
/// and the shield goes on doing its work regardless of whether this card has
/// been touched.
class PrayerChoiceCard extends ConsumerWidget {
  const PrayerChoiceCard({required this.session, super.key});

  final PrayerSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool awaiting = session.awaitingProof;
    final bool pro = ref.watch(isProProvider);
    final bool paused = ref.watch(appBlockingEnabledProvider);

    Future<void> run(Future<bool> Function() action) async {
      final bool ok = await action();
      if (!context.mounted) return;
      if (!ok) {
        context.showMessage(
          Have.enforcedAppLock
              ? 'That could not be saved. Your apps stay paused until it is.'
              : 'That could not be saved. Prayer focus stays on until it is.',
        );
      }
    }

    // No card of its own any more: this sits inside Today's Progress, and a
    // bordered box inside a bordered box reads as two separate things when it
    // is one.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(session.prayer.icon, size: 18, color: AppColors.gold),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Text(
                awaiting
                    ? '${session.prayer.label} — one step left'
                    : 'It is time for ${session.prayer.label}',
                style: AppType.titleMd,
              ),
            ),
          ],
        ),
        const SizedBox(height: Insets.xs),
        Text(
          awaiting
              ? 'Your photo finishes it. Until then this prayer is not '
                    'confirmed.'
              // "Paused" is Apple's word for what Screen Time does. Android
              // has no such thing — the focus brings Layla Pro back over
              // whatever you opened — so on Android it says what is actually
              // true, in the same words the shield itself uses.
              : paused && Have.enforcedAppLock
              ? 'Your apps are paused. Any of these three releases them.'
              : paused
              ? 'Prayer focus is on. Any of these three ends it.'
              : 'Any of these three moves the day on.',
          style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
        ),
        const SizedBox(height: Insets.lg),

        // What each answer actually does.
        //
        // The three differ in ways nobody can guess: one keeps the streak, one
        // ends it, one leaves the prayer open. Someone deciding under a paused
        // phone should not have to find that out by picking wrong — "which
        // button costs me my streak" is a question an app should answer before
        // it is asked, not after.
        if (!awaiting) ...<Widget>[
          _Note(
            icon: Icons.check_rounded,
            text: pro
                ? 'Praying now — confirm with a photo of your mat. Counts '
                      'towards your streak.'
                : 'Praying now — one tap confirms it. Counts towards your '
                      'streak.',
          ),
          _Note(
            icon: Icons.schedule_rounded,
            text: paused && Have.enforcedAppLock
                ? 'Later — apps come back, the prayer stays open, and you '
                      'can still confirm it today.'
                : paused
                ? 'Later — the focus ends, the prayer stays open, and you '
                      'can still confirm it today.'
                : 'Later — the prayer stays open, and you can still confirm '
                      'it today.',
          ),
          const _Note(
            icon: Icons.close_rounded,
            text:
                'Did not pray — recorded as missed, and it breaks the '
                'streak.',
          ),
          const SizedBox(height: Insets.lg),
        ],

        PrimaryButton(
          // Premium confirms in two steps, the second being the mat scan.
          // Everyone else confirms with one honest tap, and the streak moves
          // the same way.
          label: !pro
              ? 'I have prayed'
              : awaiting
              ? 'Scan your prayer mat'
              : 'I have prayed',
          icon: awaiting && pro
              ? Icons.center_focus_strong_rounded
              : Icons.check_rounded,
          // The camera opens over this card and comes back to it.
          onPressed: pro
              ? () => confirmWithScan(context, ref, session)
              : () => run(() async {
                  final bool ok = await ref
                      .read(prayerLockControllerProvider.notifier)
                      .confirmWithoutProof(session);
                  if (ok && context.mounted) {
                    context.showSuccess(
                      '${session.prayer.label} confirmed. May it be accepted.',
                    );
                  }
                  return ok;
                }),
        ),

        // Shown, not hidden. A free confirmation is one tap and the streak
        // moves the same way; the paid alternative used to be drawn nowhere
        // at all, so this screen said nothing about it existing and read as
        // a broken feature rather than a paid one.
        if (!pro && !awaiting) const MatScanOffer(),

        // Step 1 is still a commitment: once it is pressed the photo is the
        // only way on, or the second step would mean nothing.
        if (!awaiting) ...<Widget>[
          const SizedBox(height: Insets.xs),
          TextButton(
            onPressed: () => run(
              () => ref
                  .read(prayerLockControllerProvider.notifier)
                  .deferUntilHome(session),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.mist),
            child: const Text('I will pray when I am home'),
          ),
          TextButton(
            onPressed: () => run(
              () => ref
                  .read(prayerLockControllerProvider.notifier)
                  .markMissed(session),
            ),
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            child: const Text('I did not pray this one'),
          ),
        ],
      ],
    );
  }
}
