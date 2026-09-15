import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/result.dart';

extension SnackbarX on BuildContext {
  void showMessage(String message, {IconData? icon}) =>
      _show(this, message, AppColors.navyElevated, icon ?? Icons.info_outline);

  void showSuccess(String message) =>
      _show(this, message, AppColors.emeraldDeep, Icons.check_rounded);

  void showError(Object error) {
    final String message = error is AppFailure
        ? error.message
        : AppFailure.from(error).message;
    _show(this, message, const Color(0xFF6E2733), Icons.error_outline_rounded);
  }
}

void _show(BuildContext context, String message, Color color, IconData icon) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        content: Row(
          children: <Widget>[
            Icon(icon, size: 19, color: AppColors.cream),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppType.bodySm.copyWith(color: AppColors.cream),
              ),
            ),
          ],
        ),
      ),
    );
}
