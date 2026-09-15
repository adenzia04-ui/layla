import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../streaks/domain/prayer_day.dart';
import '../application/cycle_controller.dart';
import '../domain/cycle.dart';
import 'cycle_sheets.dart';

/// Today, as the Today's Progress card should draw it for this person.
///
/// The companion to [buildCycleChoices], and it exists because that function
/// answers from the profile while the card's summary above it answers from the
/// day document — and during a pause those two disagree until the catch-up
/// write comes back. The panel would be saying "these prayers are not owed"
/// while the header above it said "0 of 5 confirmed". Reading the same
/// provider here is what keeps one card telling one story.
///
/// Returns [day] untouched when no pause is on, so a brother's day and an
/// ordinary day are the same object they always were. See
/// [PrayerDay.asExcused] for why this is done at Home rather than in the
/// provider every other screen shares.
///
/// Gated on the same two things as [buildCycleChoices], and it has to be both.
/// A profile that somehow carries a pause for someone who is not a sister —
/// an answer changed, a document edited — gets the choices handed back
/// untouched there, so blanking the summary here on the pause alone would
/// leave him looking at a day with no count and five dashes he has no way to
/// explain. Either the whole card knows about the pause or none of it does.
PrayerDay cycleDayFor(WidgetRef ref, PrayerDay day) =>
    ref.watch(isSisterProvider) && ref.watch(cycleActiveProvider)
    ? day.asExcused()
    : day;

/// What goes in the Today's Progress card's `choices` slot for this person.
///
/// A function rather than a widget that hides itself, and deliberately so.
/// A brother, or anyone whose gender was never answered, must not have a
/// widget of this feature anywhere in his tree — not an empty one, not a
/// zero-height one. Returning early here is the difference between "it renders
/// nothing" and "it is not there", and only the second is true privacy.
///
/// Three outcomes:
/// * not a sister — [choices] untouched, exactly as Home built them;
/// * paused — [CyclePausedPanel] **instead of** [choices], because the three
///   prayer answers are meaningless on a day that is not being recorded;
/// * otherwise — [choices] with a quiet [CyclePauseRow] under them, or the row
///   on its own when no prayer window is open.
Widget? buildCycleChoices(
  WidgetRef ref, {
  required Widget? choices,
  required DateTime now,
}) {
  if (!ref.watch(isSisterProvider)) return choices;

  final Cycle cycle = ref.watch(cycleProvider);
  if (cycle.isActive) {
    return CyclePausedPanel(
      dayNumber: cycle.dayCount(now),
      askIfEnded: cycle.isLongerThanUsual(now),
    );
  }

  if (choices == null) return const CyclePauseRow();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      choices,
      // A hairline, the same one the card already uses between its summary and
      // its choices. Without it the row sat flush under "I did not pray this
      // one" and read as a fourth answer to today's prayer, which it is not —
      // it answers a different question entirely, about a week rather than a
      // prayer. The rule is the same one the card is built on: a line means
      // "different subject below".
      const SizedBox(height: Insets.md),
      const Divider(height: 1, color: AppColors.navyLine),
      const CyclePauseRow(),
    ],
  );
}

/// The way in, while prayers are being recorded as normal.
///
/// A soft line under the three answers rather than a fourth button beside
/// them. It is not one of the day's choices — it is a different kind of thing
/// entirely — and giving it the same weight as "I have prayed" would put a
/// private matter at the loudest point on the home screen.
class CyclePauseRow extends ConsumerWidget {
  const CyclePauseRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watched, not read. The row needs the busy state anyway — two taps on a
    // sheet-and-write this slow is easy — but the subscription is doing a
    // second job: `cycleControllerProvider` is auto-disposed, and a notifier
    // reached only by `ref.read` from a widget that never watches it is thrown
    // away on the next microtask, long before the two Firestore writes in
    // `start()` return. Its own `state =` after the await then lands on a dead
    // element and throws, so the bool saying whether the pause was saved never
    // arrives at all.
    final bool busy = ref.watch(cycleControllerProvider).isLoading;

    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        child: InkWell(
          onTap: busy ? null : () => _confirmStart(context, ref),
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Padding(
            // Vertical padding carries the tap target to a comfortable size;
            // the text alone is about nineteen points tall, which is not
            // something to aim a thumb at.
            padding: const EdgeInsets.symmetric(
              vertical: Insets.md,
              horizontal: Insets.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.pause_circle_outline_rounded,
                  size: 15,
                  color: AppColors.mistFaint,
                ),
                const SizedBox(width: Insets.sm),
                // Flexible, not a bare Text: at 1.3x Dynamic Type on a 375pt
                // phone this label is wider than the card, and in a release
                // build the overflow is invisible — it just clips.
                Flexible(
                  child: Text(
                    'Pause prayers for these days',
                    style: AppType.bodySm.copyWith(color: AppColors.mist),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pause itself, standing where the prayer choices would be.
class CyclePausedPanel extends ConsumerWidget {
  const CyclePausedPanel({
    required this.dayNumber,
    this.askIfEnded = false,
    super.key,
  });

  /// 1 on the first day.
  final int dayNumber;

  /// Whether the pause has run long enough to be worth one gentle question —
  /// see [Cycle.askAfterDays], which is where that judgement is made and where
  /// the reasoning for the number lives.
  ///
  /// Asking is the whole of it. Nothing on this screen, or anywhere else in
  /// Layla Pro, ends a pause on its own: it ends when the bleeding stops and
  /// she has performed ghusl, and she is the only one who knows that.
  final bool askIfEnded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool busy = ref.watch(cycleControllerProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(
              Icons.pause_circle_outline_rounded,
              size: 18,
              color: AppColors.mist,
            ),
            const SizedBox(width: Insets.sm),
            // Expanded rather than Spacer: at 1.3x the title and the day chip
            // together are wider than the card, and a Spacer cannot give way.
            Expanded(child: Text('Prayers are paused', style: AppType.titleMd)),
            const SizedBox(width: Insets.sm),
            _DayChip(dayNumber: dayNumber),
          ],
        ),
        const SizedBox(height: Insets.xs),
        // The one thing she should not have to wonder about. These prayers are
        // not owed — there is no qada for them — and the chain she has been
        // keeping is not being broken behind her back.
        Text(
          'These prayers are not owed. Nothing is recorded, nothing is missed, '
          'and your streak is waiting where you left it.',
          style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
        ),
        if (askIfEnded) ...<Widget>[
          const SizedBox(height: Insets.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.help_outline_rounded,
                  size: 13,
                  color: AppColors.goldDim,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Still paused? Resume whenever it has ended — this stays on '
                  'until you say so.',
                  style: AppType.bodySm.copyWith(
                    fontSize: 11,
                    color: AppColors.goldDim,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: Insets.lg),
        // Outlined rather than filled. It is the only action in the card, so
        // it has to be unmistakable, but a gold pill here would read as the
        // thing to do — and the one rule this feature has is that ending the
        // pause is hers to decide, not something the screen leans on.
        GhostButton(
          label: 'Resume prayers',
          icon: Icons.play_arrow_rounded,
          onPressed: busy ? null : () => _confirmEnd(context, ref),
        ),
      ],
    );
  }
}

/// "Day 3".
class _DayChip extends StatelessWidget {
  const _DayChip({required this.dayNumber});

  final int dayNumber;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: Radii.chip,
        border: Border.all(color: AppColors.navyLine),
      ),
      child: Text(
        'Day $dayNumber',
        style: AppType.bodySm.copyWith(
          fontSize: 12,
          color: AppColors.mist,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Asks, then starts — and says so when it could not.
///
/// The failure here is asymmetric in the worst direction. She has just read a
/// sheet promising that nothing is owed and that reminders stop. If the write
/// does not land, the three prayer choices stay where they were, the reminders
/// go on firing, the lock goes on raising its shield, and the day stays
/// answerable — so prayers she does not owe get recorded and the streak she
/// was told was safe breaks, with nothing on screen having said a word.
Future<void> _confirmStart(BuildContext context, WidgetRef ref) async {
  final bool? yes = await showCycleStartSheet(context);
  if (yes != true) return;
  final bool saved = await ref.read(cycleControllerProvider.notifier).start();
  if (!saved && context.mounted) {
    context.showMessage(
      'That could not be saved. Your prayers are not '
      'paused yet.',
    );
  }
}

/// The mirror, and it fails the same way in reverse: she taps Resume, the
/// reminders do not come back, and nothing explains why.
Future<void> _confirmEnd(BuildContext context, WidgetRef ref) async {
  final bool? yes = await showCycleEndSheet(context);
  if (yes != true) return;
  final bool saved = await ref.read(cycleControllerProvider.notifier).end();
  if (!saved && context.mounted) {
    context.showMessage('That could not be saved. Prayers are still paused.');
  }
}
