import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../application/starred_duas.dart';
import '../domain/dua_catalogue.dart';
import '../domain/dua_text.dart';
import 'dua_text_detail_screen.dart';

/// The whole book as clean text, browsed exactly the way the page images are:
/// categories, then sections, then the dua itself.
///
/// Categories and section numbers come from [duaCategories] rather than from
/// the text file, so the two views cannot drift into disagreeing about what
/// belongs under Sleep or Travel.
class DuaTestScreen extends StatelessWidget {
  const DuaTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NightScaffold(
      title: 'Dua Text',
      showOrnaments: false,
      scrollable: true,
      child: FutureBuilder<Map<int, DuaTextSection>>(
        future: loadDuaText(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<Map<int, DuaTextSection>> snap,
            ) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(Insets.xxl),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final Map<int, DuaTextSection> text = snap.requireData;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: Insets.md),
                  Text(
                    'From Fortress of the Muslim, as text you can read rather than '
                    'a picture of the page.',
                    style: AppType.bodySm.copyWith(color: AppColors.mist),
                  ),
                  const SizedBox(height: Insets.lg),
                  for (final DuaCategory category in duaCategories) ...<Widget>[
                    _CategoryCard(category: category, text: text),
                    const SizedBox(height: Insets.sm),
                  ],
                  const SizedBox(height: Insets.xxl),
                ],
              );
            },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.text});

  final DuaCategory category;
  final Map<int, DuaTextSection> text;

  @override
  Widget build(BuildContext context) {
    // Sections, matching the picture library — the same category showing 13
    // there and 25 here would just look like one of them was wrong. It is also
    // the number of rows that actually open when this card is tapped, since
    // anything without text behind it is dropped.
    final int rows = category.sections
        .where((DuaSection s) => text.containsKey(s.number))
        .length;

    return NightCard(
      padding: const EdgeInsets.all(Insets.lg),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              _TextCategoryScreen(category: category, text: text),
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
            '$rows',
            style: AppType.numeral.copyWith(
              fontSize: 13,
              color: AppColors.mist,
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.mistFaint,
          ),
        ],
      ),
    );
  }
}

/// The sections inside one category.
class _TextCategoryScreen extends StatelessWidget {
  const _TextCategoryScreen({required this.category, required this.text});

  final DuaCategory category;
  final Map<int, DuaTextSection> text;

  @override
  Widget build(BuildContext context) {
    // A section with no text behind it is left out rather than shown as a row
    // that opens onto nothing.
    final List<DuaSection> covered = category.sections
        .where((DuaSection s) => text.containsKey(s.number))
        .toList();

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
          for (final DuaSection s in covered) ...<Widget>[
            NightCard(
              padding: const EdgeInsets.all(Insets.lg),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => _SectionScreen(
                    section: text[s.number]!,
                    heading: s.title,
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(s.title, style: AppType.titleSm),
                        if (s.subtitle != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            s.subtitle!,
                            style: AppType.bodySm.copyWith(
                              color: AppColors.mistFaint,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  Text(
                    '${text[s.number]!.duas.length}',
                    style: AppType.numeral.copyWith(
                      fontSize: 13,
                      color: AppColors.mist,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.mistFaint,
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.sm),
          ],
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}

class _SectionScreen extends ConsumerWidget {
  const _SectionScreen({required this.section, required this.heading});

  final DuaTextSection section;

  /// The catalogue's wording for this section. The source edition's own titles
  /// are long and inconsistent, and the library already shows the short ones.
  final String heading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<int> starred = ref.watch(starredDuasProvider);
    final List<DuaText> ordered = starredFirst(
      section.duas,
      starred,
      (DuaText d) => d.number,
    );

    return NightScaffold(
      title: heading,
      showOrnaments: false,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.md),
          for (final DuaText dua in ordered) ...<Widget>[
            NightCard(
              padding: const EdgeInsets.all(Insets.lg),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => DuaTextDetailScreen(
                    dua: dua,
                    sectionTitle: section.title,
                    sectionNumber: section.section,
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              'Dua ${dua.number}',
                              style: AppType.label.copyWith(
                                color: AppColors.goldSoft,
                              ),
                            ),
                            if (starred.contains(dua.number)) ...<Widget>[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.star_rounded,
                                size: 13,
                                color: AppColors.gold,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // A preview, not the whole thing — the point of the
                        // list is choosing, not reading.
                        Text(
                          dua.english,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.bodySm.copyWith(color: AppColors.mist),
                        ),
                      ],
                    ),
                  ),
                  // The star sits in the row, not behind a long-press or a swipe:
                  // picking favourites out of twenty-four is the job, and a hidden
                  // gesture would make it a hunt.
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    tooltip: starred.contains(dua.number)
                        ? 'Remove from favourites'
                        : 'Keep at the top',
                    icon: Icon(
                      starred.contains(dua.number)
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 21,
                      color: starred.contains(dua.number)
                          ? AppColors.gold
                          : AppColors.mistFaint,
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      ref.read(starredDuasProvider.notifier).toggle(dua.number);
                    },
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.mistFaint,
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
