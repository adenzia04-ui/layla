import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/platform_features.dart';
import '../../premium/application/premium_store.dart';
import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/avatar_circle.dart';
import '../../../core/widgets/noor_flame.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/presentation/widgets/sign_out.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../streaks/application/streak_controller.dart';
import '../../streaks/domain/prayer_day.dart';
import '../application/avatar_controller.dart';
import '../domain/avatar.dart';

/// Whether this phone is on a guest account.
///
/// Its own provider rather than a read of the repository, for the same reason
/// `friendsGuestProvider` is one: the screen can then be rendered with nothing
/// behind it, so a golden or a widget test overrides this single value and
/// needs no Firebase at all.
final Provider<bool> profileGuestProvider = Provider<bool>(
  (Ref ref) => ref.watch(authRepositoryProvider).isGuest,
);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(appUserProvider).valueOrNull;
    final UserStats stats = ref.watch(userStatsProvider);
    // Counted for this calendar year; the streams rebuild on 1 January.
    final StreakHistory? year = ref.watch(streakHistoryProvider).valueOrNull;
    final int thisYear = DateTime.now().year;
    final int prayersThisYear = year?.totalConfirmed ?? 0;
    final int nightsThisYear =
        year?.days.values.where((PrayerDay d) => d.tahajjudPrayed).length ?? 0;
    final bool isGuest = ref.watch(profileGuestProvider);

    return NightScaffold(
      scrollable: true,
      ornamentHeight: 240,
      leading: CircleIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        onPressed: () => context.pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.xxxl),
          Row(
            children: <Widget>[
              _ProfileAvatar(user: user),
              const SizedBox(width: Insets.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user?.displayName.isNotEmpty ?? false
                          ? user!.displayName
                          : 'Guest',
                      style: AppType.displayMd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isGuest
                          ? 'Guest account · this device only'
                          : (user?.email ?? ''),
                      style: AppType.bodySm.copyWith(color: AppColors.mist),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.xl),
          if (isGuest) ...<Widget>[
            _UpgradeBanner(onTap: () => context.push(Routes.signup)),
            const SizedBox(height: Insets.xl),
          ],
          const SectionHeader(label: 'Prayer statistics'),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatCard(
                  label: 'Current streak',
                  value: '${stats.streakOn(DateTime.now())}',
                  suffix: stats.currentStreak == 1 ? 'day' : 'days',
                  icon: Icons.local_fire_department_rounded,
                  iconWidget: const NoorFlame(size: 22, glow: false),
                  color: AppColors.ember,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: _StatCard(
                  label: 'Longest streak',
                  value: '${stats.longestStreak}',
                  suffix: stats.longestStreak == 1 ? 'day' : 'days',
                  icon: Icons.emoji_events_outlined,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _StatCard(
                  label: 'Prayers confirmed',
                  value: '$prayersThisYear',
                  suffix: 'in $thisYear',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: _StatCard(
                  label: 'Tahajjud nights',
                  value: '$nightsThisYear',
                  suffix: 'in $thisYear',
                  icon: Icons.bedtime_outlined,
                  color: AppColors.goldSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Prayers and nights are counted for $thisYear and start again from '
            'zero on 1 January.',
            style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
          ),
          const SizedBox(height: Insets.xl),
          const SectionHeader(label: 'Settings'),
          NightCard(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: Column(
              children: <Widget>[
                _MenuRow(
                  icon: Icons.workspace_premium_outlined,

                  // Says out loud which build this is. The paid features
                  // are open only when a build asked for it with
                  // --dart-define=LAYLA_UNLOCK_ALL=true; without it the
                  // prayer-mat scan and the paid counters behave as they will
                  // for a real customer. Knowing which of the two you are
                  // holding is the difference between "the camera is broken"
                  // and "this build is not Premium".
                  label: kUnlockAllForTesting
                      ? 'Layla Pro Premium · unlocked for testing'
                      : 'Layla Pro Premium',

                  onTap: () => context.push(Routes.paywall),
                ),
                _MenuRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Account',
                  onTap: () => context.push(Routes.accountSettings),
                ),
                _MenuRow(
                  icon: Icons.notifications_none_rounded,
                  label: 'Reminders & prayer focus',
                  onTap: () => context.push(Routes.notificationSettings),
                ),
                _MenuRow(
                  icon: Icons.tune_rounded,
                  label: 'Prayer calculation',
                  onTap: () => context.go(Routes.prayerSettings),
                ),
                // Android has no widget extension to colour, so the row
                // that leads to one is not shown there.
                if (Have.widgetColourSets)
                  _MenuRow(
                    icon: Icons.palette_outlined,
                    label: 'Widgets & colours',
                    onTap: () => context.push(Routes.widgetTheme),
                  ),
                _MenuRow(
                  icon: Icons.local_fire_department_outlined,
                  label: 'Prayer streak',
                  onTap: () => context.go(Routes.streak),
                ),
                _MenuRow(
                  icon: Icons.menu_book_outlined,
                  label: 'Tahajjud stories',
                  onTap: () => context.go(Routes.stories),
                  last: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          NightCard(
            onTap: () => confirmSignOut(context, ref),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: AppColors.rose,
                ),
                const SizedBox(width: Insets.md),
                Text(
                  'Log out',
                  style: AppType.titleSm.copyWith(color: AppColors.rose),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xxl),
          Center(
            child: Text(
              'Layla Pro · v1.0.0',
              style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
            ),
          ),
          const SizedBox(height: Insets.xl),
        ],
      ),
    );
  }
}

/// Your own face at the top of your profile, and the way to change it.
///
/// The circle is the same [AvatarCircle] a friend gets, which is deliberate:
/// one avatar in the app means your picture is drawn, and falls back, exactly
/// the way theirs does. What marks this one as yours is that it can be tapped
/// — hence the small camera badge, since a circle that does nothing anywhere
/// else in the app gives no hint that this one does.
class _ProfileAvatar extends ConsumerWidget {
  const _ProfileAvatar({required this.user});

  /// Null while the profile document is still loading, and when signed out.
  final AppUser? user;

  static const double _size = 64;

  /// The badge, sized so that at [_size] its centre lands on the rim at
  /// roughly four o'clock rather than sitting inside the picture.
  static const double _badge = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool busy = ref.watch(avatarControllerProvider).isLoading;
    final String? photo = user?.photo;
    final bool hasPhoto = Avatar.isUsable(photo);
    // Nothing to write to until the profile document has arrived.
    final bool canEdit = user != null;
    // Nothing to do either while a picture is already on its way.
    final VoidCallback? edit = busy || !canEdit
        ? null
        : () => _openAvatarSheet(context, ref, hasPhoto: hasPhoto);

    // The badge hangs off the rim, outside the circle, and the circle's own
    // InkWell is clipped to a CircleBorder — so a tap on the camera icon, the
    // one thing on screen advertising that this avatar can be changed, lands
    // on nothing. This detector catches the whole square the badge lives in;
    // the InkWell below still gives the circle its ripple.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: edit,
      child: Stack(
        // The badge sits on the rim, so it has to be allowed outside the box.
        clipBehavior: Clip.none,
        children: <Widget>[
          AvatarCircle(
            initials: user?.initials ?? '?',
            photo: photo,
            size: _size,
            // Your own circle keeps the gold disc it has always had when
            // there is no picture on it.
            gilded: true,
            onTap: edit,
          ),
          if (canEdit)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: _badge,
                height: _badge,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.navy,
                  border: Border.all(color: AppColors.gold, width: 1),
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(3.5),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.gold,
                        ),
                      )
                    : const Icon(
                        Icons.photo_camera_rounded,
                        size: 11,
                        color: AppColors.gold,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

/// What the picture sheet can end in.
enum _AvatarChoice { choose, remove }

/// Offers the two things that can be done to a profile picture, then does the
/// one that was chosen.
///
/// The failure is read back out of the controller rather than caught here: the
/// controller keeps it in its state, the same way [FriendsActions] does, so a
/// picker that was simply cancelled cannot be mistaken for one that failed.
Future<void> _openAvatarSheet(
  BuildContext context,
  WidgetRef ref, {
  required bool hasPhoto,
}) async {
  final _AvatarChoice? choice = await showModalBottomSheet<_AvatarChoice>(
    context: context,
    // Above the shell's floating bar, not beneath it.
    useRootNavigator: true,
    backgroundColor: AppColors.navy,
    builder: (BuildContext context) => SafeArea(
      top: false,
      child: Padding(
        // The same top inset every other sheet in the app uses, so the title
        // sits the same distance under the theme's drag handle as it does on
        // the friend sheet this one opens next to.
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
            Text('Profile picture', style: AppType.displaySm),
            const SizedBox(height: Insets.sm),
            Text(
              'Kept with your account and shown to the friends you have '
              'added. Nobody else can see it.',
              style: AppType.bodySm.copyWith(color: AppColors.mist),
            ),
            const SizedBox(height: Insets.lg),
            NightCard(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: Column(
                children: <Widget>[
                  _MenuRow(
                    icon: Icons.photo_library_outlined,
                    label: 'Choose a photo',
                    onTap: () =>
                        Navigator.of(context).pop(_AvatarChoice.choose),
                    last: !hasPhoto,
                  ),
                  if (hasPhoto)
                    _MenuRow(
                      icon: Icons.delete_outline_rounded,
                      label: 'Remove photo',
                      color: AppColors.rose,
                      onTap: () =>
                          Navigator.of(context).pop(_AvatarChoice.remove),
                      last: true,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (choice == null || !context.mounted) return;

  final AvatarController controller = ref.read(
    avatarControllerProvider.notifier,
  );
  switch (choice) {
    case _AvatarChoice.choose:
      await controller.pickAndSave(context);
    case _AvatarChoice.remove:
      await controller.remove();
  }
  if (!context.mounted) return;

  final Object? error = ref.read(avatarControllerProvider).error;
  if (error != null) context.showError(error);
}

class _UpgradeBanner extends StatelessWidget {
  const _UpgradeBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      onTap: onTap,
      borderColor: AppColors.gold,
      child: Row(
        children: <Widget>[
          const Icon(Icons.shield_outlined, color: AppColors.gold, size: 22),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Save your streak', style: AppType.titleMd),
                const SizedBox(height: 2),
                Text(
                  'Add an email and password to keep your history, unlock the '
                  'Tahajjud map and share stories.',
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.color,
    this.iconWidget,
  });

  final String label;
  final String value;
  final String suffix;
  final IconData icon;
  final Color color;

  /// Replaces [icon] when set — used for the painted streak flame.
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          iconWidget ?? Icon(icon, size: 20, color: color),
          const SizedBox(height: Insets.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(value, style: AppType.clock.copyWith(fontSize: 28)),
              const SizedBox(width: 4),
              Text(
                suffix,
                style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: AppType.bodySm.copyWith(color: AppColors.mist)),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Tints the whole row. Only the destructive one in the picture sheet uses
  /// it; a settings row is never coloured.
  final Color? color;

  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Insets.lg),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(
                  bottom: BorderSide(
                    color: AppColors.navyLine.withValues(alpha: 0.5),
                  ),
                ),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 20, color: color ?? AppColors.mist),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Text(
                label,
                style: color == null
                    ? AppType.titleSm
                    : AppType.titleSm.copyWith(color: color),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.mistFaint,
            ),
          ],
        ),
      ),
    );
  }
}
