import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/noor_flame.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../streaks/application/streak_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: Text('Log out?', style: AppType.titleLg),
        content: Text(
          ref.read(authRepositoryProvider).isGuest
              ? 'You are using a guest account. Logging out will permanently '
                  'lose your streak and history — there is no way to sign back '
                  'into a guest account.'
              : 'You can sign back in any time and your streak will be waiting.',
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
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final bool ok = await ref.read(authControllerProvider.notifier).signOut();
    if (ok && context.mounted) context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppUser? user = ref.watch(appUserProvider).value;
    final UserStats stats = ref.watch(userStatsProvider);
    final bool isGuest = ref.watch(authRepositoryProvider).isGuest;

    return NightScaffold(
      scrollable: true,
      ornamentHeight: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.xl),
          Row(
            children: <Widget>[
              Container(
                height: 64,
                width: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.goldSheen,
                ),
                alignment: Alignment.center,
                child: Text(
                  user?.initials ?? '?',
                  style: AppType.displaySm.copyWith(
                    color: AppColors.midnight,
                    fontSize: 24,
                  ),
                ),
              ),
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
                  value: '${stats.currentStreak}',
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
                  value: '${stats.totalPrayers}',
                  suffix: 'total',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: _StatCard(
                  label: 'Tahajjud nights',
                  value: '${stats.totalTahajjud}',
                  suffix: 'total',
                  icon: Icons.bedtime_outlined,
                  color: AppColors.goldSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.xl),
          const SectionHeader(label: 'Settings'),
          NightCard(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: Column(
              children: <Widget>[
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
            onTap: () => _signOut(context, ref),
            child: Row(
              children: <Widget>[
                const Icon(Icons.logout_rounded,
                    size: 20, color: AppColors.rose,),
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
              'Layla · v1.0.0',
              style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
            ),
          ),
          const SizedBox(height: Insets.xl),
        ],
      ),
    );
  }
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
          Text(
            label,
            style: AppType.bodySm.copyWith(color: AppColors.mist),
          ),
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
    this.last = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
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
            Icon(icon, size: 20, color: AppColors.mist),
            const SizedBox(width: Insets.md),
            Expanded(child: Text(label, style: AppType.titleSm)),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.mistFaint,),
          ],
        ),
      ),
    );
  }
}
