import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../domain/dua_catalogue.dart';
import '../domain/dua_pages.dart';
import '../domain/dua_text.dart';
import 'dua_page_screen.dart';

/// One supplication, set as text.
///
/// The printed page is always one tap away. The page is the authority; this is
/// the reading view. If the two ever disagree, the book wins — and you can see
/// it without leaving the screen.
class DuaTextDetailScreen extends StatelessWidget {
  const DuaTextDetailScreen({
    super.key,
    required this.dua,
    required this.sectionTitle,
    required this.sectionNumber,
  });

  final DuaText dua;
  final String sectionTitle;
  final int sectionNumber;

  @override
  Widget build(BuildContext context) {
    final PageRange range = duaSectionPages[sectionNumber] ??
        (start: 1, end: 1);

    return NightScaffold(
      title: sectionTitle,
      showOrnaments: false,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Text(
                'DUA ${dua.number}',
                style: AppType.label.copyWith(color: AppColors.goldSoft),
              ),
              if (dua.repeat > 1) ...<Widget>[
                const SizedBox(width: Insets.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.16),
                    borderRadius: Radii.chip,
                  ),
                  child: Text(
                    '×${dua.repeat}',
                    style: AppType.label.copyWith(color: AppColors.gold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: Insets.lg),

          // Arabic first and largest, right-aligned, with generous line
          // height — vocalized Arabic needs the room or the harakat collide.
          NightCard(
            padding: const EdgeInsets.all(Insets.xl),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                dua.arabic,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontSize: 26,
                  height: 2.0,
                  color: AppColors.cream,
                ),
              ),
            ),
          ),
          const SizedBox(height: Insets.lg),

          _Block(label: 'Transliteration', body: dua.transliteration),
          _Block(label: 'Translation', body: dua.english),

          const SizedBox(height: Insets.sm),
          NightCard(
            padding: const EdgeInsets.all(Insets.lg),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => DuaPageScreen(
                  section: DuaSection(
                    number: sectionNumber,
                    title: sectionTitle,
                    page: range.start,
                  ),
                ),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.menu_book_rounded,
                  size: 19,
                  color: AppColors.gold,
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('View in the book', style: AppType.titleSm),
                      Text(
                        'Fortress of the Muslim, page ${range.start}'
                        '${range.end > range.start ? '–${range.end}' : ''}'
                        ' — with its reference',
                        style: AppType.bodySm.copyWith(
                          fontSize: 11,
                          color: AppColors.mistFaint,
                        ),
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
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppType.label.copyWith(color: AppColors.mistFaint),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppType.bodySm.copyWith(
              color: AppColors.cream,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
