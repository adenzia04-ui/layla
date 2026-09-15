import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../circles/application/circles_controller.dart';
import '../../../circles/domain/circle.dart';
import '../../../circles/presentation/circle_picker_sheet.dart';
import '../../application/friends_controller.dart';
import '../../domain/friend.dart';
import 'friend_avatar.dart';
import 'friend_lines.dart';
import 'friend_numbers.dart';
import 'milestone_badge.dart';
import 'verse_picker.dart';

/// A friend, opened: the same numbers as the card, larger, their code, and
/// the way to part.
Future<void> showFriendSheet(BuildContext context, Friend friend) {
  // The add-a-friend field may still own the keyboard when a card is tapped.
  // Let go of it first: the sheet has nothing to type into, and a keyboard
  // left up would only push it off the bottom of the screen.
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<void>(
    context: context,
    // Above the shell's floating bar, not beneath it.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.navy,
    builder: (BuildContext context) => _FriendSheet(friend: friend),
  );
}

class _FriendSheet extends ConsumerWidget {
  const _FriendSheet({required this.friend});

  final Friend friend;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: Text('Remove ${friend.name}?', style: AppType.titleLg),
        content: Text(
          'You will stop seeing each other\'s prayers. Either of you can add '
          'the other again with a code.',
          style: AppType.bodySm.copyWith(color: AppColors.mist),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;

    try {
      await ref.read(friendsActionsProvider.notifier).remove(friend.uid);
    } on Object catch (error) {
      if (context.mounted) context.showError(error);
      return;
    }
    if (!context.mounted) return;
    // The controller may keep the failure in its state rather than throw it.
    final Object? error = ref.read(friendsActionsProvider).error;
    if (error != null) {
      context.showError(error);
      return;
    }
    // Said before the sheet goes, while this context can still reach the
    // messenger; the bar itself outlives the sheet.
    context.showMessage('${friend.name} removed.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A friend added a moment ago has no `since` yet: the list entry is still
    // a local write waiting for the server's clock, and the server may not
    // hold it at all. Opening the progress listener before it does turns it
    // into a permission error that never clears, so it waits for the stamp.
    final AsyncValue<FriendProgress?> progress = friend.since == null
        ? const AsyncValue<FriendProgress?>.loading()
        : ref.watch(friendProgressProvider(friend.uid));
    final FriendProgress? p = progress.valueOrNull;
    final bool busy = ref.watch(friendsActionsProvider).isLoading;
    final bool quiet = p?.quiet ?? false;
    final int completed = p != null && p.prayedToday ? p.todayCompleted : 0;
    final DateTime? since = friend.since;
    final DateTime? updatedAt = p?.updatedAt;
    final Milestone? fresh = quiet ? null : p?.milestone;
    // Half theirs, half yours: hidden the moment either side is quiet.
    final int together = quiet || ref.watch(quietProvider)
        ? 0
        : ref.watch(togetherProvider(friend.uid)) ?? 0;
    // "Invite to a circle" only when there is a circle to invite them to.
    final bool hasCircles =
        (ref.watch(circlesProvider).valueOrNull ?? const <Circle>[]).isNotEmpty;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Insets.xl,
          Insets.sm,
          Insets.xl,
          Insets.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                FriendAvatar(
                  initials: friend.initials,
                  photo: p?.photo,
                  size: 56,
                ),
                const SizedBox(width: Insets.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        friend.name,
                        style: AppType.displaySm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        FriendCode.display(friend.code),
                        style: AppType.numeral.copyWith(
                          color: AppColors.gold,
                          letterSpacing: 3,
                        ),
                      ),
                      if (since != null) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          'Friends since ${Fmt.shortDate(since)}',
                          style: AppType.bodySm.copyWith(
                            color: AppColors.mistFaint,
                          ),
                        ),
                      ],
                      if (fresh != null && fresh.isFresh) ...<Widget>[
                        const SizedBox(height: Insets.sm),
                        MilestoneBadge(milestone: fresh.key),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.xl),
            if (p == null)
              Text(
                'No progress shared yet. It appears here once they open '
                'Layla Pro.',
                style: AppType.body.copyWith(color: AppColors.mist),
              )
            else if (quiet)
              Text(
                'Quiet for now. Their numbers are hidden until they choose '
                'otherwise — you can still send them a verse.',
                style: AppType.body.copyWith(color: AppColors.mist),
              )
            else ...<Widget>[
              Row(
                children: <Widget>[
                  PrayerDots(completed: completed, size: 12),
                  const SizedBox(width: Insets.md),
                  Flexible(
                    child: Text(
                      FriendNumbers.today(completed),
                      style: AppType.titleSm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.lg),
              NightCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.sm,
                  vertical: Insets.lg,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _Stat(
                          icon: Icons.local_fire_department_rounded,
                          color: AppColors.ember,
                          value: FriendNumbers.count(p.streakToday),
                          label: 'day streak',
                        ),
                      ),
                      const _Hairline(),
                      Expanded(
                        child: _Stat(
                          icon: Icons.check_circle_outline_rounded,
                          color: AppColors.emerald,
                          value: FriendNumbers.count(p.totalPrayers),
                          label: 'prayers',
                        ),
                      ),
                      const _Hairline(),
                      Expanded(
                        child: _Stat(
                          icon: Icons.bedtime_outlined,
                          color: AppColors.goldSoft,
                          value: FriendNumbers.count(p.totalTahajjud),
                          label: 'Tahajjud nights',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Insets.md),
              Text(
                <String>[
                  'Longest streak ${FriendNumbers.days(p.longestStreak)}',
                  if (updatedAt != null) 'Updated ${Fmt.relative(updatedAt)}',
                ].join(' · '),
                style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
              ),
              if (together > 0)
                FriendLine(
                  icon: Icons.people_alt_outlined,
                  text: since == null
                      ? FriendNumbers.together(together)
                      : '${FriendNumbers.together(together)} since '
                            '${Fmt.shortDate(since)}',
                ),
            ],
            const SizedBox(height: Insets.xxl),
            // Two things to give, above the one way to part.
            GhostButton(
              label: 'Send a verse',
              icon: Icons.menu_book_outlined,
              onPressed: busy ? null : () => showVersePicker(context, friend),
            ),
            if (hasCircles) ...<Widget>[
              const SizedBox(height: Insets.sm),
              GhostButton(
                label: 'Invite to a circle',
                icon: Icons.group_add_outlined,
                onPressed: busy
                    ? null
                    : () => showCirclePicker(context, friend),
              ),
            ],
            const SizedBox(height: Insets.sm),
            // The app's ghost pill, in rose. GhostButton has no colour of its
            // own, and this is the only place one is needed.
            Theme(
              data: Theme.of(context).copyWith(
                outlinedButtonTheme: OutlinedButtonThemeData(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rose,
                    minimumSize: const Size.fromHeight(56),
                    textStyle: AppType.button,
                    side: BorderSide(
                      color: AppColors.rose.withValues(alpha: 0.55),
                    ),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              child: GhostButton(
                label: 'Remove friend',
                icon: Icons.person_remove_outlined,
                onPressed: busy ? null : () => _remove(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        const SizedBox(height: Insets.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: AppType.clock.copyWith(fontSize: 26)),
        ),
        const SizedBox(height: 2),
        // Two lines, so "Tahajjud nights" wraps in a third of a small phone
        // rather than being cut to "Tahajjud ni…".
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppType.bodySm.copyWith(
            color: AppColors.mist,
            fontSize: 12,
            height: 1.2,
          ),
          maxLines: 2,
        ),
      ],
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(vertical: Insets.xs),
    color: AppColors.navyLine.withValues(alpha: 0.7),
  );
}
