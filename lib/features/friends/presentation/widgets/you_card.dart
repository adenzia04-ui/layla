import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/avatar_circle.dart';
import '../../application/friends_controller.dart';
import '../../domain/friend.dart';
import '../../domain/jumuah.dart';
import 'friend_avatar.dart';
import 'friend_lines.dart';
import 'friend_numbers.dart';
import 'milestone_badge.dart';

/// You, at the top of the Friends list: what your friends see of you, in the
/// same shape as a friend's card, and the one switch that changes it.
///
/// The card exists so nobody has to guess what they are showing. Every number
/// here is exactly what a friend's card carries, and the Quiet switch sits
/// under them because that is what it acts on.
class YouCard extends ConsumerWidget {
  const YouCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FriendProgress? p = ref.watch(myProgressProvider);
    final bool quiet = ref.watch(quietProvider);
    final int cheers = ref.watch(cheersReceivedProvider).valueOrNull ?? 0;
    final Milestone? milestone = ref.watch(myMilestoneProvider);
    final String? uid = ref.watch(friendsUidProvider);
    final bool friday = ref.watch(isFridayProvider);
    final bool busy = ref.watch(friendsActionsProvider).isLoading;

    final int completed = p != null && p.prayedToday ? p.todayCompleted : 0;
    final int streak = quiet ? 0 : p?.streakToday ?? 0;

    return NightCard(
      // Gold, faintly: this is the one card on the list that is yours.
      borderColor: AppColors.gold.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Gilded, as on the profile: yours is the gold disc, a friend's
              // is cream on navy, and the two never read as the same person.
              AvatarCircle(
                initials: p?.initials ?? '',
                photo: p?.photo,
                gilded: true,
              ),
              const SizedBox(width: Insets.md + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: Text('You', style: AppType.titleMd)),
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
                    // While Quiet is on the publisher hands out zeros, and
                    // zeros drawn as dots and totals would read as a day
                    // nothing was prayed. What friends actually see is the
                    // honest thing to show: the same two words.
                    if (quiet)
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
                              'Quiet for now — this is all friends see.',
                              style: AppType.bodySm.copyWith(
                                color: AppColors.mist,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (p == null)
                      Text(
                        'Your numbers appear here once your code is ready.',
                        style: AppType.bodySm.copyWith(
                          color: AppColors.mistFaint,
                        ),
                      )
                    else ...<Widget>[
                      Row(
                        children: <Widget>[
                          PrayerDots(completed: completed),
                          const SizedBox(width: Insets.sm + 2),
                          Flexible(
                            child: Text(
                              FriendNumbers.today(completed),
                              style: AppType.bodySm.copyWith(
                                color: AppColors.mist,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        '${FriendNumbers.count(p.totalPrayers)} prayers · '
                        '${FriendNumbers.count(p.totalTahajjud)} Tahajjud '
                        'nights',
                        style: AppType.bodySm.copyWith(
                          color: AppColors.mistFaint,
                        ),
                        maxLines: 2,
                      ),
                    ],
                    if (milestone != null && milestone.isFresh) ...<Widget>[
                      const SizedBox(height: Insets.sm + 2),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: MilestoneBadge(milestone: milestone.key),
                      ),
                    ],
                    // Only when there is something to say. "0 friends said
                    // MashaAllah" is a line that reads as nobody caring.
                    if (cheers > 0)
                      FriendLine(
                        icon: Icons.favorite_rounded,
                        color: AppColors.goldSoft,
                        text: FriendNumbers.cheers(cheers),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          const Divider(height: 1, color: AppColors.navyLine),
          SwitchListTile.adaptive(
            value: quiet,
            onChanged: busy
                ? null
                : (bool value) => _setQuiet(context, ref, value),
            activeThumbColor: AppColors.gold,
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(
              Icons.visibility_off_outlined,
              size: 19,
              color: AppColors.mist,
            ),
            title: Text('Quiet for now', style: AppType.titleSm),
            // One sentence, and the whole of it: what the switch does is the
            // only thing anyone needs to know before touching it.
            subtitle: Text(
              'Friends see "Quiet for now" instead of your numbers until you '
              'switch this off.',
              style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
            ),
          ),
          if (friday && uid != null) ...<Widget>[
            const Divider(height: 1, color: AppColors.navyLine),
            const SizedBox(height: Insets.lg),
            _MasjidField(saved: masjidThisFriday(ref, uid), busy: busy),
          ],
        ],
      ),
    );
  }
}

/// Flips the switch, and says so when the wish could not be saved: a switch
/// that springs back with no word is a switch that looks broken.
Future<void> _setQuiet(BuildContext context, WidgetRef ref, bool value) async {
  await ref.read(friendsActionsProvider.notifier).setQuiet(value);
  if (!context.mounted) return;
  // The controller keeps a failure in its state rather than throwing it.
  final Object? error = ref.read(friendsActionsProvider).error;
  if (error != null) context.showError(error);
}

/// "Which masjid?" — the one piece of text a friend can ever read from you.
///
/// Saved on submit rather than as it is typed: forty characters is short
/// enough that the keyboard's Done is the natural end of the thought, and a
/// write per keystroke would put half-typed names on every friend's card.
class _MasjidField extends ConsumerStatefulWidget {
  const _MasjidField({required this.saved, required this.busy});

  /// What is on the server for this Friday, or null.
  final String? saved;
  final bool busy;

  @override
  ConsumerState<_MasjidField> createState() => _MasjidFieldState();
}

class _MasjidFieldState extends ConsumerState<_MasjidField> {
  late final TextEditingController _masjid = TextEditingController(
    text: widget.saved ?? '',
  );
  final FocusNode _focus = FocusNode();

  @override
  void didUpdateWidget(_MasjidField old) {
    super.didUpdateWidget(old);
    // The saved name arrives a moment after the card; take it unless the
    // person is already typing over it.
    if (old.saved != widget.saved && !_focus.hasFocus) {
      _masjid.text = widget.saved ?? '';
    }
  }

  @override
  void dispose() {
    _masjid.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String masjid = _masjid.text.trim();
    if (masjid.isEmpty) return;
    FocusScope.of(context).unfocus();
    await ref.read(friendsActionsProvider.notifier).setJumuah(masjid);
    if (!mounted) return;
    // The controller keeps a failure in its state rather than throwing it.
    final Object? error = ref.read(friendsActionsProvider).error;
    if (error != null) {
      context.showError(error);
      return;
    }
    context.showSuccess('Saved. Friends see it on your card this Friday.');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Which masjid this Friday?',
          style: AppType.bodySm.copyWith(
            color: AppColors.cream.withValues(alpha: 0.72),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _masjid,
          focusNode: _focus,
          enabled: !widget.busy,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          inputFormatters: <TextInputFormatter>[
            LengthLimitingTextInputFormatter(Jumuah.maxLength),
          ],
          onSubmitted: (_) => _save(),
          style: AppType.body.copyWith(color: AppColors.cream),
          decoration: const InputDecoration(
            hintText: 'Masjid Al-Falah',
            prefixIcon: Icon(Icons.mosque_outlined, size: 19),
          ),
        ),
        const SizedBox(height: Insets.xs + 2),
        Text(
          'Friends going to the same one will know. Nothing else is shared.',
          style: AppType.bodySm.copyWith(
            fontSize: 11,
            color: AppColors.mistFaint,
          ),
        ),
      ],
    );
  }
}
