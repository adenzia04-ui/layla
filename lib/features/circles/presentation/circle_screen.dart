import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/avatar_circle.dart';
import '../../../core/widgets/state_views.dart';
import '../../friends/application/friends_controller.dart';
import '../../friends/domain/friend.dart';
import '../../friends/presentation/widgets/friend_numbers.dart';
import '../application/circles_controller.dart';
import '../domain/circle.dart';
import 'widgets/circle_bar.dart';

/// One circle, opened: the shared bar, everyone in it and their days, the
/// code that lets someone else in, and the way out.
///
/// Members are listed in the order they joined. Not by days kept, not with
/// a "top" — the moment this page sorts people it becomes a leaderboard, and
/// a leaderboard is the one thing a shared intention must not turn into.
class CircleScreen extends ConsumerWidget {
  const CircleScreen({super.key, required this.circleId});

  final String circleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Circle?> circle = ref.watch(circleProvider(circleId));

    return NightScaffold(
      scrollable: true,
      ornamentHeight: 240,
      leading: CircleIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        tooltip: 'Back',
        onPressed: () => context.pop(),
      ),
      child: circle.when(
        loading: () => const SizedBox(height: 320, child: LoadingView()),
        error: (Object error, StackTrace stack) => ErrorView(
          message: error is FirebaseException
              ? 'This circle could not be loaded — Firestore said '
                    '"${error.code}".'
              : 'This circle could not be loaded ($error).',
          onRetry: () => ref.invalidate(circleProvider(circleId)),
        ),
        data: (Circle? c) => c == null
            ? const EmptyView(
                icon: Icons.group_off_outlined,
                title: 'Not your circle any more',
                body:
                    'You have left it, or it has gone. Join again with its '
                    'code if you were meant to be in it.',
              )
            : _CircleBody(circle: c),
      ),
    );
  }
}

class _CircleBody extends ConsumerWidget {
  const _CircleBody({required this.circle});

  final Circle circle;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: FriendCode.display(circle.code)),
    );
    if (context.mounted) context.showSuccess('Code copied');
  }

  Future<void> _share(BuildContext context) async {
    final RenderBox box = context.findRenderObject()! as RenderBox;
    await SharePlus.instance.share(
      ShareParams(
        text:
            'Join my circle "${circle.name}" on Layla Pro — forty days of '
            '${circle.goal.label.toLowerCase()}, kept together. The code is '
            '${FriendCode.display(circle.code)}.',
        sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: Text('Leave ${circle.name}?', style: AppType.titleLg),
        content: Text(
          'You will stop seeing the circle and it will stop seeing you. You '
          'can join again with the code.',
          style: AppType.bodySm.copyWith(color: AppColors.mist),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    await ref.read(circleActionsProvider.notifier).leave(circle.id);
    if (!context.mounted) return;
    // The controller keeps a failure in its state rather than throwing it.
    final Object? error = ref.read(circleActionsProvider).error;
    if (error != null) {
      context.showError(error);
      return;
    }
    // Said before the screen goes, while this context can still reach the
    // messenger; the bar itself outlives the screen.
    context.showMessage('You have left ${circle.name}.');
    context.pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = DateTime.now();
    final List<CircleProgress> progress =
        ref.watch(circleMembersProgressProvider(circle.id)).valueOrNull ??
        const <CircleProgress>[];
    final Map<String, int> keptBy = <String, int>{
      for (final CircleProgress p in progress) p.uid: p.kept,
    };
    final String? me = ref.watch(friendsUidProvider);
    final Map<String, Friend> friends = <String, Friend>{
      for (final Friend f
          in ref.watch(friendsProvider).valueOrNull ?? const <Friend>[])
        f.uid: f,
    };
    final FriendProgress? mine = ref.watch(myProgressProvider);
    final int day = circleDayOn(circle, now);
    final bool finished = circle.isOver(now);
    final DateTime? started = Fmt.parseDayId(circle.startsOn);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: Insets.xl),
        Text('TOGETHER', style: AppType.label.copyWith(color: AppColors.gold)),
        const SizedBox(height: Insets.sm),
        Text(
          circle.name,
          style: AppType.displayMd,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: Insets.sm),
        Text(
          <String>[
            circle.goal.label,
            finished
                ? 'Forty days done'
                : FriendNumbers.dayOf(day, circle.days),
            if (started != null) 'since ${Fmt.shortDate(started)}',
          ].join(' · '),
          style: AppType.body.copyWith(color: AppColors.mist),
        ),
        const SizedBox(height: Insets.xl),
        NightCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              CircleBar(
                fraction: circle.sharedFraction(progress, now),
                height: 10,
              ),
              const SizedBox(height: Insets.sm),
              Text(
                '${circleKept(circle, progress)} of ${circlePossible(circle, now)} '
                'kept so far, between you',
                style: AppType.bodySm.copyWith(
                  color: AppColors.mist,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              const SizedBox(height: Insets.lg),
              const Divider(height: 1, color: AppColors.navyLine),
              for (final String uid in circle.members)
                _MemberRow(
                  name: uid == me
                      ? 'You'
                      : friends[uid]?.name ?? 'Someone in the circle',
                  initials: uid == me
                      ? mine?.initials ?? 'Y'
                      : friends[uid]?.initials ?? '·',
                  photo: uid == me ? mine?.photo : null,
                  isMe: uid == me,
                  kept: keptBy[uid],
                  day: day,
                ),
            ],
          ),
        ),
        const SizedBox(height: Insets.xl),
        _CodePlate(
          code: circle.code,
          onCopy: () => _copy(context),
          onShare: () => _share(context),
        ),
        const SizedBox(height: Insets.xxl),
        Theme(
          data: Theme.of(context).copyWith(
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.rose,
                minimumSize: const Size.fromHeight(56),
                textStyle: AppType.button,
                side: BorderSide(color: AppColors.rose.withValues(alpha: 0.55)),
                shape: const StadiumBorder(),
              ),
            ),
          ),
          child: GhostButton(
            label: 'Leave circle',
            icon: Icons.logout_rounded,
            onPressed: () => _leave(context, ref),
          ),
        ),
      ],
    );
  }
}

/// One person in the circle and how many of the days so far they have kept.
///
/// "12 of 14 days" for everyone alike — the same words for you as for the
/// rest, so nobody's row is the loud one.
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.name,
    required this.initials,
    required this.photo,
    required this.isMe,
    required this.kept,
    required this.day,
  });

  final String name;
  final String initials;
  final String? photo;
  final bool isMe;

  /// Null until their phone has published anything.
  final int? kept;
  final int day;

  @override
  Widget build(BuildContext context) {
    final int? k = kept;
    return Padding(
      padding: const EdgeInsets.only(top: Insets.md),
      child: Row(
        children: <Widget>[
          AvatarCircle(
            initials: initials,
            photo: photo,
            size: 34,
            gilded: isMe,
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Text(
              name,
              style: AppType.titleSm,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: Insets.md),
          Text(
            k == null ? 'Not yet' : '$k of $day ${day == 1 ? 'day' : 'days'}',
            style: AppType.bodySm.copyWith(
              color: k == null ? AppColors.mistFaint : AppColors.mist,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The circle's code, drawn as the friend code is: a plate someone holds up.
class _CodePlate extends StatelessWidget {
  const _CodePlate({
    required this.code,
    required this.onCopy,
    required this.onShare,
  });

  final String code;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.lg,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.group_outlined,
                  size: 24,
                  color: AppColors.gold,
                ),
                const SizedBox(width: Insets.lg),
                Container(
                  width: 1,
                  height: 34,
                  color: AppColors.gold.withValues(alpha: 0.3),
                ),
                const SizedBox(width: Insets.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'CIRCLE CODE',
                        style: AppType.label.copyWith(color: AppColors.goldDim),
                      ),
                      const SizedBox(height: Insets.xs),
                      Text(
                        FriendCode.display(code),
                        style: AppType.displayMd.copyWith(
                          color: AppColors.gold,
                          letterSpacing: 6,
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Anyone with this code can join, up to ${Circle.maxMembers} of '
            'you. Friends can also be invited from their card.',
            style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _PlateAction(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onPressed: onCopy,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: _PlateAction(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  onPressed: onShare,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlateAction extends StatelessWidget {
  const _PlateAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: Insets.md),
        foregroundColor: AppColors.cream,
        textStyle: AppType.titleSm,
        side: BorderSide(color: AppColors.navyLine.withValues(alpha: 0.9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 17),
          const SizedBox(width: Insets.sm),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
