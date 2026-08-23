import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../domain/dua_catalogue.dart';
import 'dua_page_screen.dart';

/// The sections inside a category — for Prayer, every position in order.
class DuaCategoryScreen extends StatelessWidget {
  const DuaCategoryScreen({super.key, required this.category});

  final DuaCategory category;

  @override
  Widget build(BuildContext context) {
    return NightScaffold(
      title: category.title,
      showOrnaments: false,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.md),
          Text(
            category.description,
            style: AppType.bodySm.copyWith(color: AppColors.mist),
          ),
          const SizedBox(height: Insets.lg),
          for (final DuaSection section in category.sections) ...<Widget>[
            NightCard(
              padding: const EdgeInsets.all(Insets.lg),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) =>
                      DuaPageScreen(section: section),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(section.title, style: AppType.titleSm),
                        if (section.subtitle != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            section.subtitle!,
                            style: AppType.bodySm
                                .copyWith(color: AppColors.mistFaint),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '§${section.number} · page ${section.page}',
                          style: AppType.bodySm.copyWith(
                            fontSize: 11,
                            color: AppColors.mistFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: section.hasText
                        ? AppColors.mistFaint
                        : AppColors.mistFaint.withValues(alpha: 0.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.sm),
          ],
        ],
      ),
    );
  }
}
