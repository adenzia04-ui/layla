import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/presentation/widgets/sign_out.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  final TextEditingController _name = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final String? error = Validate.name(_name.text);
    if (error != null) {
      context.showError(error);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updateDisplayName(_name.text);
      if (mounted) context.showSuccess('Name updated.');
    } on Object catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: Text('Delete your account?', style: AppType.titleLg),
        content: Text(
          'This permanently removes your profile, streak, prayer history, '
          'stories and every prayer-mat photo. It cannot be undone.',
          style: AppType.bodySm.copyWith(color: AppColors.mist),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep my account'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final bool ok = await ref
        .read(authControllerProvider.notifier)
        .deleteAccount();
    if (!mounted) return;
    ok
        ? context.go(Routes.login)
        : context.showError(
            'Your account could not be deleted. Log out and back in, then try '
            'again.',
          );
  }

  @override
  Widget build(BuildContext context) {
    final AppUser? user = ref.watch(appUserProvider).valueOrNull;
    final bool isGuest = ref.watch(authRepositoryProvider).isGuest;

    if (!_seeded && user != null) {
      _name.text = user.displayName;
      _seeded = true;
    }

    return NightScaffold(
      scrollable: true,
      ornamentHeight: 180,
      title: 'Account',
      leading: CircleIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        onPressed: () => context.pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.xxxl),
          const SectionHeader(label: 'Your details'),
          AppTextField(
            controller: _name,
            label: 'Name',
            hint: 'What should we call you?',
            validator: Validate.name,
          ),
          NightCard(
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.alternate_email_rounded,
                  size: 19,
                  color: AppColors.mist,
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Text(
                    isGuest
                        ? 'No email — this is a guest account'
                        : (user?.email ?? ''),
                    style: AppType.bodySm.copyWith(color: AppColors.mist),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.lg),
          PrimaryButton(
            label: 'Save changes',
            busy: _saving,
            onPressed: _saveName,
          ),
          if (isGuest) ...<Widget>[
            const SizedBox(height: Insets.xl),
            const SectionHeader(label: 'Upgrade'),
            NightCard(
              onTap: () => context.push(Routes.signup),
              borderColor: AppColors.gold,
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.shield_outlined,
                    color: AppColors.gold,
                    size: 20,
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Text(
                      'Add an email and password to keep your streak safe.',
                      style: AppType.bodySm.copyWith(color: AppColors.mist),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.mistFaint,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Insets.xxl),
          const SectionHeader(label: 'This device'),
          NightCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Log out', style: AppType.titleSm),
                const SizedBox(height: Insets.sm),
                Text(
                  isGuest
                      ? 'A guest account cannot be signed back into. Logging '
                            'out loses your streak and history for good.'
                      : 'Signs you out on this phone only. Your streak and '
                            'history stay on your account, waiting for you.',
                  style: AppType.bodySm.copyWith(
                    color: isGuest ? AppColors.mist : AppColors.mistFaint,
                  ),
                ),
                const SizedBox(height: Insets.lg),
                GhostButton(
                  label: 'Log out',
                  icon: Icons.logout_rounded,
                  onPressed: () => confirmSignOut(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xxl),
          const SectionHeader(label: 'Danger zone'),
          NightCard(
            borderColor: AppColors.rose.withValues(alpha: 0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Delete account', style: AppType.titleSm),
                const SizedBox(height: Insets.sm),
                Text(
                  'Removes your profile, streak, prayer history, stories and '
                  'every prayer-mat photo. This cannot be undone.',
                  style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                ),
                const SizedBox(height: Insets.lg),
                GhostButton(
                  label: 'Delete my account',
                  icon: Icons.delete_forever_outlined,
                  onPressed: _deleteAccount,
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}
