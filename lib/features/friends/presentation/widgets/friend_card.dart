import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../application/friends_controller.dart';
import '../../domain/friend.dart';
import 'friend_avatar.dart';
import 'friend_lines.dart';
import 'friend_numbers.dart';
import 'milestone_badge.dart';

/// The milestones this phone has said MashaAllah to since the app opened,
/// as "uid:key".
///
/// Session memory, not a document: the sender may never read the cheer back
/// (only its recipient can), so the button's disabled state has nowhere else
/// to live. A second cheer after a relaunch overwrites the first harmlessly.
final StateProvider<Set<String>> cheeredProvider = StateProvider<Set<String>>(
  (Ref ref) => <String>{},
);

/// One friend on the list: who they are, and how today and the long run are
/// going for them.
///
/// The streak sits on the name line rather than among the totals. It is the
/// number a friend actually asks about, and on a 375pt phone the day's dots,
/// the "3 of 5" and the flame do not all fit on one line anyway.
///
/// A friend who has gone quiet is a name, a face and the words "Quiet for
/// now". Not one number — not the streak, not the totals, not the prayers
/// kept together, not even "updated 2h ago". Quiet means quiet.
class FriendCard extends ConsumerWidget {
  const FriendCard({super.key, required this.friend, required this.onTap});

  final Friend friend;
  final VoidCallback onTap;

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
    final bool quiet = p?.quiet ?? false;
    // Their counter is stamped with the day it was written on. A friend who
    // has not opened the app since yesterday still carries yesterday's five,
    // and showing those as today's would be a small lie.
    final int completed = p != null && p.prayedToday ? p.todayCompleted : 0;
    // The chain as it stands now, not as it was last written; a lapsed one
    // reads 0 and gets no flame — a flame beside "0 days" is a taunt.
    final int streak = quiet ? 0 : p?.streakToday ?? 0;
    final DateTime? updatedAt = p?.updatedAt;
    final String? masjid = masjidThisFriday(ref, friend.uid);
    // Only during Ramadan, and only what they published for it.
    final RamadanShare? ramadanShare = ref.watch(isRamadanProvider)
        ? p?.ramadan
        : null;

    return NightCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          FriendAvatar(initials: friend.initials, photo: p?.photo),
          const SizedBox(width: Insets.md + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        friend.name,
                        style: AppType.titleMd,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (streak > 0) ...<Widget>[
                      const SizedBox(width: Insets.sm),
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 16,
                        color: AppColors.ember,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        FriendNumbers.days(streak),
                        style: AppType.titleSm.copyWith(
                          color: AppColors.mist,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: Insets.sm),
                if (p == null)
                  Text(
                    progress.isLoading ? ' ' : 'No progress shared yet',
                    style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                  )
                else if (quiet) ...<Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.visibility_off_outlined,
                        size: 14,
                        color: AppColors.mistFaint,
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Quiet for now',
                          style: AppType.bodySm.copyWith(color: AppColors.mist),
                        ),
                      ),
                    ],
                  ),
                  // The masjid is a thing they chose to say, not a number
                  // they are keeping to themselves; it stays.
                  if (masjid != null)
                    FriendLine(
                      icon: Icons.mosque_outlined,
                      text: '$masjid this Friday',
                    ),
                ] else ...<Widget>[
                  Row(
                    children: <Widget>[
                      PrayerDots(completed: completed),
                      const SizedBox(width: Insets.sm + 2),
                      Flexible(
                        child: Text(
                          FriendNumbers.today(completed),
                          style: AppType.bodySm.copyWith(color: AppColors.mist),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.xs),
                  // Free to wrap: "1,240 prayers · 312 Tahajjud nights" is
                  // wider than a small phone's card, and a cut total is
                  // worse than a second line.
                  Text(
                    '${FriendNumbers.count(p.totalPrayers)} prayers · '
                    '${FriendNumbers.count(p.totalTahajjud)} Tahajjud nights',
                    style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                    maxLines: 2,
                  ),
                  if (p.milestone case final Milestone m
                      when m.isFresh) ...<Widget>[
                    const SizedBox(height: Insets.sm + 2),
                    // A Wrap, not a Row: "100 Tahajjud nights" and the button
                    // do not share a line on a small phone at 1.3x, and a
                    // second line is the right answer.
                    Wrap(
                      spacing: Insets.sm,
                      runSpacing: Insets.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        MilestoneBadge(milestone: m.key),
                        _MashaAllahButton(friend: friend, milestone: m.key),
                      ],
                    ),
                  ],
                  _TogetherLine(friend: friend),
                  if (masjid != null)
                    FriendLine(
                      icon: Icons.mosque_outlined,
                      text: '$masjid this Friday',
                    ),
                  if (ramadanShare case final RamadanShare r)
                    FriendLine(
                      icon: Icons.nightlight_outlined,
                      color: AppColors.goldSoft,
                      // "Fasting today" only on the day it was said; a
                      // share from yesterday still carries yesterday's yes.
                      text: r.fastingToday && r.isForDay(DateTime.now())
                          ? 'Fasting today · ${FriendNumbers.fasts(r.fasts)}'
                          : '${FriendNumbers.fasts(r.fasts)} this Ramadan',
                      trailing: r.taraweeh ? const TaraweehMoon() : null,
                    ),
                  if (updatedAt != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      'Updated ${Fmt.relative(updatedAt)}',
                      style: AppType.bodySm.copyWith(
                        color: AppColors.mistFaint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "240 prayers together since 20 Aug" — what the two of you have kept
/// between you since the day you became friends.
///
/// Hidden when either side is quiet: the number is half theirs and half
/// yours, and neither half may be shown around a "Quiet for now".
class _TogetherLine extends ConsumerWidget {
  const _TogetherLine({required this.friend});

  final Friend friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(quietProvider)) return const SizedBox.shrink();
    final int together = ref.watch(togetherProvider(friend.uid)) ?? 0;
    if (together <= 0) return const SizedBox.shrink();
    final DateTime? since = friend.since;
    return FriendLine(
      icon: Icons.people_alt_outlined,
      text: since == null
          ? FriendNumbers.together(together)
          : '${FriendNumbers.together(together)} since '
                '${Fmt.shortDate(since)}',
    );
  }
}

/// "MashaAllah" — one tap, once, on a friend's fresh milestone.
///
/// It disables the moment it is tapped rather than when the write returns:
/// the point is that it can be said once, and a button that stays live for
/// a second after saying it invites a second tap.
class _MashaAllahButton extends ConsumerWidget {
  const _MashaAllahButton({required this.friend, required this.milestone});

  final Friend friend;
  final MilestoneKey milestone;

  String get _id => '${friend.uid}:${milestone.key}';

  Future<void> _cheer(BuildContext context, WidgetRef ref) async {
    final StateController<Set<String>> cheered = ref.read(
      cheeredProvider.notifier,
    );
    cheered.state = <String>{...cheered.state, _id};
    await ref
        .read(friendsActionsProvider.notifier)
        .cheer(friend.uid, milestone);
    if (!context.mounted) return;
    // The controller keeps a failure in its state rather than throwing it.
    final Object? error = ref.read(friendsActionsProvider).error;
    if (error == null) return;
    // Not said after all: the button comes back so it can be tried again.
    cheered.state = <String>{...cheered.state}..remove(_id);
    context.showError(error);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool said = ref.watch(cheeredProvider).contains(_id);
    return OutlinedButton.icon(
      onPressed: said ? null : () => _cheer(context, ref),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        disabledForegroundColor: AppColors.gold.withValues(alpha: 0.7),
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: Insets.md),
        textStyle: AppType.titleSm.copyWith(fontSize: 13),
        side: BorderSide(
          color: AppColors.gold.withValues(alpha: said ? 0.25 : 0.6),
        ),
        shape: const StadiumBorder(),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(
        said ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: 15,
      ),
      label: Text(said ? 'MashaAllah said' : 'MashaAllah'),
    );
  }
}
