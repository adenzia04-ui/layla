import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../application/auth_controller.dart';
import '../../data/auth_repository.dart';

/// Asks, then signs out.
///
/// Shared by the Profile screen and Account settings. The warning a guest sees
/// is the whole reason this is one function rather than two copies: logging out
/// of a guest account destroys a streak permanently and there is no way back
/// in. A second copy of that dialog would be one edit away from losing the
/// warning, and nobody would notice until somebody lost their history.
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
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
  if (!context.mounted) return;
  final bool ok = await ref.read(authControllerProvider.notifier).signOut();
  if (ok && context.mounted) context.go(Routes.login);
}
