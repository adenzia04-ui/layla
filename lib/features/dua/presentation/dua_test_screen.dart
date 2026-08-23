import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../domain/dua_text.dart';
import 'dua_text_detail_screen.dart';

/// A trial of the clean-text presentation, alongside — not instead of — the
/// page images. Prayer only for now, so the quality can be judged against the
/// book before the other 121 sections are attempted.
class DuaTestScreen extends StatelessWidget {
  const DuaTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return NightScaffold(
      title: 'Test',
      showOrnaments: false,
      scrollable: true,
      child: FutureBuilder<List<DuaTextSection>>(
        future: loadPrayerText(),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<DuaTextSection>> snap,
        ) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(Insets.xxl),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final List<DuaTextSection> sections = snap.requireData;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: Insets.md),
              Text(
                'Prayer, as clean text. Every dua keeps the book’s own number '
                'and opens the printed page for checking.',
                style: AppType.bodySm.copyWith(color: AppColors.mist),
              ),
              const SizedBox(height: Insets.lg),
              for (final DuaTextSection s in sections) ...<Widget>[
                NightCard(
                  padding: const EdgeInsets.all(Insets.lg),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          _SectionScreen(section: s),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(s.title, style: AppType.titleSm),
                            const SizedBox(height: 2),
                            Text(
                              '${s.duas.length} '
                              '${s.duas.length == 1 ? 'dua' : 'duas'} · '
                              '§${s.section}',
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
                const SizedBox(height: Insets.sm),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionScreen extends StatelessWidget {
  const _SectionScreen({required this.section});

  final DuaTextSection section;

  @override
  Widget build(BuildContext context) {
    return NightScaffold(
      title: section.title,
      showOrnaments: false,
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.md),
          for (final DuaText dua in section.duas) ...<Widget>[
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
                        Text(
                          'Dua ${dua.number}',
                          style: AppType.label
                              .copyWith(color: AppColors.goldSoft),
                        ),
                        const SizedBox(height: 4),
                        // A preview, not the whole thing — the point of the
                        // list is choosing, not reading.
                        Text(
                          dua.english,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              AppType.bodySm.copyWith(color: AppColors.mist),
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
            const SizedBox(height: Insets.sm),
          ],
        ],
      ),
    );
  }
}
