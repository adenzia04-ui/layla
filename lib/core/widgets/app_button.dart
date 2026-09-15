import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The filled pill from the onboarding reference — black on light sheets,
/// gold on the night sky. Handles its own busy state so callers never have to
/// juggle a spinner.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.busy = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget child = busy
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: scheme.onPrimary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 19),
                const SizedBox(width: Insets.sm),
              ],
              // Flexible, not a bare Text: at 1.3x Dynamic Type on a 375pt
              // phone a long label ('I will pray when I am home') is wider
              // than the button, and a Row with nothing shrinkable overflows.
              // In release that overflow is invisible — it just clips.
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ],
          );

    final Widget button = FilledButton(
      onPressed: busy ? null : onPressed,
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// The outlined companion — "Sign up" under "Log in".
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget button = OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 19),
            const SizedBox(width: Insets.sm),
          ],
          // Flexible, not a bare Text: at 1.3x Dynamic Type on a 375pt
          // phone a long label ('I will pray when I am home') is wider
          // than the button, and a Row with nothing shrinkable overflows.
          // In release that overflow is invisible — it just clips.
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Small circular icon button used for back arrows on light sheets.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: background ?? scheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: 20,
        color: foreground ?? scheme.onSurface,
        icon: Icon(icon),
      ),
    );
  }
}

/// Gold-bordered chip used for the "in 1hr 10min" countdown and for filters.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.gold : Colors.transparent,
      borderRadius: Radii.chip,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.chip,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: Insets.sm + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: Radii.chip,
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.navyLine,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 15,
                  color: selected ? AppColors.midnight : AppColors.mist,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppType.titleSm.copyWith(
                  color: selected ? AppColors.midnight : AppColors.mist,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
