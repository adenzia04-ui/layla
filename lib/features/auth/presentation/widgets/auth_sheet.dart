import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/night_hero.dart';

/// The auth layout from the reference: night mosque behind, a light rounded
/// sheet in front carrying the form.
class AuthSheet extends StatelessWidget {
  const AuthSheet({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.onBack,
    this.heroFlex = 3,
    this.sheetFlex = 7,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final VoidCallback? onBack;

  /// Ratio of hero to sheet — signup needs more sheet than login.
  final int heroFlex;
  final int sheetFlex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: <Widget>[
          const NightHero(),
          Column(
            // The sheet must span the full width; the Container it replaced
            // did that with `width: double.infinity`.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(flex: heroFlex, child: const SizedBox.shrink()),
              Expanded(
                flex: sheetFlex,
                child: Theme(
                  data: AppTheme.light,
                  // Material, not Container: `Theme` alone swaps ThemeData but
                  // does not republish DefaultTextStyle, so any Text without an
                  // explicit colour keeps inheriting the *dark* theme's cream —
                  // invisible on this cream sheet. Material is what re-applies
                  // the theme's text style to its descendants.
                  child: Material(
                    color: AppColors.bone,
                    borderRadius: Radii.sheet,
                    clipBehavior: Clip.antiAlias,
                    child: SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          left: Insets.xxl,
                          right: Insets.xxl,
                          top: Insets.xl,
                          bottom:
                              MediaQuery.viewInsetsOf(context).bottom +
                              Insets.xxl,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                if (onBack != null)
                                  CircleIconButton(
                                    icon: Icons.arrow_back_ios_new_rounded,
                                    onPressed: onBack,
                                    tooltip: 'Back',
                                    background: AppColors.boneMuted,
                                    foreground: AppColors.ink,
                                  ),
                                const Spacer(),
                              ],
                            ),
                            const SizedBox(height: Insets.lg),
                            Text(title, style: AppType.displayLg),
                            if (subtitle != null) ...<Widget>[
                              const SizedBox(height: Insets.sm),
                              Text(
                                subtitle!,
                                style: AppType.body.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                            const SizedBox(height: Insets.xxl),
                            ...children,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Word-mark used above the sheet and on the splash screen.
class NoorWordmark extends StatelessWidget {
  const NoorWordmark({super.key, this.color = AppColors.cream, this.size = 30});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    'noor',
    style: AppType.displayMd.copyWith(
      fontSize: size,
      color: color,
      fontStyle: FontStyle.italic,
      letterSpacing: 1,
    ),
  );
}
