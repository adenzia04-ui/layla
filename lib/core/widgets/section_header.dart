import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// "MAIN FEATURES ————————— " with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.label,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md, top: Insets.sm),
      child: Row(
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppType.label.copyWith(color: AppColors.gold),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.navyLine.withValues(alpha: 0.7),
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.only(left: Insets.md),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}
