import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../domain/dua_catalogue.dart';
import 'dua_category_screen.dart';

/// The categories, in the order the book presents them.
class DuaLibraryScreen extends StatelessWidget {
  const DuaLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NightScaffold(
      title: 'Dua Categories',
      showOrnaments: false,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.md),
          Text(
            'From Fortress of the Muslim — invocations from the Qur’an and '
            'Sunnah.',
            style: AppType.bodySm.copyWith(color: AppColors.mist),
          ),
          const SizedBox(height: Insets.lg),
          for (final DuaCategory category in duaCategories) ...<Widget>[
            _CategoryCard(category: category),
            const SizedBox(height: Insets.sm),
          ],
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final DuaCategory category;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      padding: const EdgeInsets.all(Insets.lg),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              DuaCategoryScreen(category: category),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(category.icon, size: 22, color: AppColors.gold),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(category.title, style: AppType.titleSm),
                const SizedBox(height: 2),
                Text(
                  category.description,
                  style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          Text(
            '${category.count}',
            style: AppType.numeral.copyWith(
              fontSize: 13,
              color: AppColors.mist,
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.mistFaint),
        ],
      ),
    );
  }
}
