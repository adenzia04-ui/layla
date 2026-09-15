import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/tasbih_beads.dart';
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
          Text('Soul', style: AppType.displayLg),
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
                builder: (BuildContext context) => const DuaTestScreen(),
              ),
            ),
          ),
          const SizedBox(height: Insets.md),
          _Entry(
            title: 'Mood',
            description: 'A verse or hadith for how you feel',
            accent: PrayerPalette.maghrib.end,
            icon: Icon(
              Icons.favorite_outline_rounded,
              size: 26,
              color: PrayerPalette.maghrib.end,
            ),
            onTap: () => context.push(Routes.mood),
          ),
          const SizedBox(height: Insets.md),
          _Entry(
            title: 'Friends',
            description: 'Your people, and how their prayers are going',
            accent: AppColors.pulse,
            icon: const Icon(
              Icons.people_alt_rounded,
              size: 26,
              color: AppColors.pulse,
            ),
            onTap: () => context.push(Routes.friends),
          ),
          const SizedBox(height: Insets.md),
          _Entry(
            title: 'Names of Allah',
            description: 'One of the Ninety-Nine, each day',
            accent: AppColors.goldSoft,
            icon: const Icon(
              Icons.auto_awesome_rounded,
              size: 26,
              color: AppColors.goldSoft,
            ),
            onTap: () => context.push(Routes.soulNames),
          ),
          const SizedBox(height: Insets.md),
          _Entry(
            title: 'Prayer streak',
            description: 'A whole year of prayer, one dot a day',
            accent: AppColors.ember,
            icon: const Icon(
              Icons.local_fire_department_rounded,
              size: 26,
              color: AppColors.ember,
            ),
            onTap: () => context.push(Routes.streak),
          ),
          const SizedBox(height: Insets.md),
          _Entry(
            title: 'Qibla',
            description: 'The bearing to the Kaaba from where you are',
            accent: AppColors.pulseSoft,
            icon: const Icon(
              Icons.explore_rounded,
              size: 26,
              color: AppColors.pulseSoft,
            ),
            onTap: () => context.push(Routes.qibla),
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
          const Icon(Icons.chevron_right_rounded, color: AppColors.mistFaint),
        ],
      ),
    );
  }
}
