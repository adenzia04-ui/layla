import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/layla_mark.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/state_views.dart';
import '../../circles/presentation/widgets/together_section.dart';
import '../application/friends_controller.dart';
import '../domain/friend.dart';
import 'widgets/add_friend_field.dart';
import 'widgets/friend_card.dart';
import 'widgets/friend_code_card.dart';
import 'widgets/friend_sheet.dart';
import 'widgets/inbox_strip.dart';
import 'widgets/you_card.dart';
import '../../../core/widgets/platform_icons.dart';

/// Whether the person on this phone has no account Friends can work with —
/// a guest, or nobody signed in.
///
/// Its own provider rather than a read of the repository, so the screen can
/// be rendered with nothing behind it: a preview or a golden overrides this
/// one value and needs no Firebase at all.
final Provider<bool> friendsGuestProvider = Provider<bool>(
  (Ref ref) => ref.watch(friendsUidProvider) == null,
);

/// Your code, a field for a friend's, and the people who have exchanged one
/// with you — with how their prayers are going.
class FriendsScreen extends ConsumerWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isGuest = ref.watch(friendsGuestProvider);

    return NightScaffold(
      scrollable: true,
      ornamentHeight: 240,
      leading: CircleIconButton(
        icon: kBackIcon,
        tooltip: 'Back',
        onPressed: () => context.pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.xl),
          Text('Friends', style: AppType.displayLg),
          const SizedBox(height: Insets.sm),
          // Not what the hub entry already said; the one thing the screen
          // is for, in a sentence.
          Text(
            'A code each. Then you can see whether the other one prayed today.',
            style: AppType.body.copyWith(color: AppColors.mist),
          ),
          const SizedBox(height: Insets.xl),
          if (isGuest)
            const _GuestCard()
          else ...<Widget>[
            // What friends have sent, then you as they see you, then the
            // two things that make a friendship, then the friends.
            const InboxStrip(),
            const YouCard(),
            const SizedBox(height: Insets.xxl),
            const SectionHeader(label: 'Your code'),
            const FriendCodeCard(),
            const SizedBox(height: Insets.xxl),
            const SectionHeader(label: 'Add a friend'),
            const AddFriendField(),
            const SizedBox(height: Insets.xxl),
            const _FriendsList(),
            const SizedBox(height: Insets.xxl),
            const TogetherSection(),
          ],
        ],
      ),
    );
  }
}

/// The list itself, or the reason there is none yet.
class _FriendsList extends ConsumerWidget {
  const _FriendsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Friend>> friends = ref.watch(friendsProvider);
    return friends.when(
      loading: () => const SizedBox(height: 160, child: LoadingView()),
      // The real message, as the streak screen does: a missing rule and a
      // dropped connection look the same behind a polite constant, and they
      // are fixed in different places.
      error: (Object error, StackTrace stack) => ErrorView(
        message: error is FirebaseException
            ? 'Your friends could not be loaded — Firestore said '
                  '"${error.code}".'
            : 'Your friends could not be loaded ($error).',
        onRetry: () => ref.invalidate(friendsProvider),
      ),
      data: (List<Friend> list) {
        if (list.isEmpty) return const _NoFriendsYet();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionHeader(label: 'Friends · ${list.length}'),
            for (int i = 0; i < list.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: Insets.md),
              FriendCard(
                friend: list[i],
                onTap: () => showFriendSheet(context, list[i]),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Nobody on the list yet: the mark, and what the two things above it are for.
class _NoFriendsYet extends StatelessWidget {
  const _NoFriendsYet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.xl,
        vertical: Insets.xxxl,
      ),
      child: Column(
        children: <Widget>[
          const Opacity(opacity: 0.85, child: LaylaMark(height: 44)),
          const SizedBox(height: Insets.xl),
          Text(
            'No friends yet',
            textAlign: TextAlign.center,
            style: AppType.displaySm,
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Share your code, or add a friend\'s. You will see each other\'s '
            'prayers, streaks and Tahajjud nights.',
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: AppColors.mist),
          ),
        ],
      ),
    );
  }
}

/// What a guest sees in place of the code: the one thing Friends needs.
///
/// Sends them to sign-up, not the welcome screen — for a guest that is the
/// upgrade path, and it keeps the uid, so the streak really does come along.
class _GuestCard extends StatelessWidget {
  const _GuestCard();

  @override
  Widget build(BuildContext context) {
    return NightCard(
      borderColor: AppColors.gold.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(Insets.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const LaylaMark(height: 22),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text('Friends need an account', style: AppType.titleMd),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Sign in and your streak comes with you.',
            style: AppType.body.copyWith(color: AppColors.mist),
          ),
          const SizedBox(height: Insets.lg),
          PrimaryButton(
            label: 'Sign in',
            onPressed: () => context.push(Routes.signup),
          ),
        ],
      ),
    );
  }
}
