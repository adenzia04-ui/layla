import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/tasbih_beads.dart';
import 'dua_library_screen.dart';
import 'dua_test_screen.dart';

/// The hub the tab now opens onto: dhikr on one side, supplications on the
/// other.
///
/// The counter itself is untouched — this sits in front of it rather than
/// replacing it, so nothing about the existing Tasbih screen changes.
class TasbihDuaHomeScreen extends StatelessWidget {
  const TasbihDuaHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NightScaffold(
      ornamentHeight: 220,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.xl),
          Text('Tasbih + Dua', style: AppType.displayLg),
          const SizedBox(height: Insets.sm),
          Text(
            'Remember Allah. Make Dhikr. Learn authentic supplications.',
            style: AppType.bodySm.copyWith(color: AppColors.mist),
          ),
          const SizedBox(height: Insets.xxl),
          _Entry(
            title: 'Tasbih',
            description: 'Count your dhikr with ease',
            accent: AppColors.emerald,
            icon: const TasbihBeads(size: 30),
            onTap: () => context.push(Routes.tasbihCounter),
          ),
          const SizedBox(height: Insets.md),
          _Entry(
            title: 'Duas',
            description: 'Supplications from the Qur’an and Sunnah',
            accent: AppColors.gold,
            icon: const Icon(
              Icons.menu_book_rounded,
              size: 28,
              color: AppColors.gold,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const DuaLibraryScreen(),
              ),
            ),
          ),
          const SizedBox(height: Insets.md),
          _Entry(
            title: 'Test',
            description: 'Clean text trial — Prayer duas, page still one tap away',
            accent: AppColors.amber,
            icon: const Icon(
              Icons.science_rounded,
              size: 26,
              color: AppColors.amber,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const DuaTestScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.title,
    required this.description,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final Color accent;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Insets.xl),
      child: Row(
        children: <Widget>[
          SizedBox(width: 44, height: 44, child: Center(child: icon)),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppType.titleLg),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: AppType.bodySm.copyWith(color: AppColors.mist),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.mistFaint,
          ),
        ],
      ),
    );
  }
}
