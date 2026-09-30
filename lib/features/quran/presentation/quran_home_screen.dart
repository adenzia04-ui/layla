import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../application/quran_prefs.dart';
import '../domain/quran_data.dart';

/// The Qur'an: the mushaf as printed, or the reader with the words beside
/// their meaning — and the 114 surahs to open either from.
class QuranHomeScreen extends ConsumerStatefulWidget {
  const QuranHomeScreen({super.key});

  @override
  ConsumerState<QuranHomeScreen> createState() => _QuranHomeScreenState();
}

class _QuranHomeScreenState extends ConsumerState<QuranHomeScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Quran> quran = ref.watch(quranProvider);
    final String? lastRead = ref.watch(lastReadProvider);
    final int lastPage = ref.watch(lastPageProvider);

    return NightScaffold(
      title: 'Qur’an',
      leading: BackButton(
        color: AppColors.cream,
        onPressed: () => context.pop(),
      ),
      showOrnaments: false,
      padding: EdgeInsets.zero,
      child: quran.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Text(
            'The Qur’an could not be opened.\n$e',
            textAlign: TextAlign.center,
            style: AppType.bodySm.copyWith(color: AppColors.mist),
          ),
        ),
        data: (Quran q) {
          final List<Surah> surahs = q.surahs.where((Surah s) {
            if (_query.isEmpty) return true;
            final String needle = _query.toLowerCase();
            return s.name.toLowerCase().contains(needle) ||
                s.meaning.toLowerCase().contains(needle) ||
                s.arabicName.contains(_query) ||
                s.number.toString() == _query;
          }).toList();

          final Ayah? resume = _resume(q, lastRead);

          return CustomScrollView(
            slivers: <Widget>[
              SliverPadding(
                padding: Insets.pageH,
                sliver: SliverList(
                  delegate: SliverChildListDelegate(<Widget>[
                    const SizedBox(height: Insets.md),
                    if (resume != null) ...<Widget>[
                      _Resume(
                        title: 'Continue reading',
                        line:
                            '${q.surah(resume.surah).name} · Ayah ${resume.number}',
                        icon: Icons.bookmark_rounded,
                        onTap: () => context.push(
                          '${Routes.quranSurah(resume.surah)}?ayah=${resume.number}',
                        ),
                      ),
                      const SizedBox(height: Insets.md),
                    ],
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _Mode(
                            title: 'Mushaf',
                            line: 'The Madinah pages, as printed',
                            detail: lastPage > 1
                                ? 'Page $lastPage'
                                : '604 pages',
                            icon: Icons.auto_stories_rounded,
                            onTap: () => context.push(Routes.quranMushaf),
                          ),
                        ),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: _Mode(
                            title: 'Read & listen',
                            line: 'Arabic, transliteration, translation',
                            detail: 'Tafsir · 4 reciters',
                            icon: Icons.translate_rounded,
                            onTap: () => context.push(
                              resume == null
                                  ? Routes.quranSurah(1)
                                  : '${Routes.quranSurah(resume.surah)}?ayah=${resume.number}',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Insets.xl),
                    TextField(
                      controller: _search,
                      onChanged: (String v) =>
                          setState(() => _query = v.trim()),
                      style: AppType.body.copyWith(color: AppColors.cream),
                      decoration: InputDecoration(
                        hintText: 'Find a surah — name, meaning or number',
                        hintStyle: AppType.bodySm.copyWith(
                          color: AppColors.mistFaint,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.mistFaint,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: AppColors.mistFaint,
                                ),
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        filled: true,
                        fillColor: AppColors.navyElevated,
                        border: const OutlineInputBorder(
                          borderRadius: Radii.card,
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.page,
                  0,
                  Insets.page,
                  40,
                ),
                sliver: SliverList.separated(
                  itemCount: surahs.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: Insets.sm),
                  itemBuilder: (BuildContext context, int i) =>
                      _SurahRow(surah: surahs[i]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Ayah? _resume(Quran q, String? key) {
    if (key == null) return null;
    final List<String> parts = key.split(':');
    if (parts.length != 2) return null;
    final int? s = int.tryParse(parts[0]);
    final int? a = int.tryParse(parts[1]);
    if (s == null || a == null || s < 1 || s > 114) return null;
    final List<Ayah> ayahs = q.ayahsOf(s);
    if (a < 1 || a > ayahs.length) return null;
    return ayahs[a - 1];
  }
}

class _Resume extends StatelessWidget {
  const _Resume({
    required this.title,
    required this.line,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String line;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      onTap: onTap,
      borderColor: AppColors.gold.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(Insets.lg),
      child: Row(
        children: <Widget>[
          Icon(icon, color: AppColors.gold, size: 22),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: AppType.titleSm),
                Text(
                  line,
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

class _Mode extends StatelessWidget {
  const _Mode({
    required this.title,
    required this.line,
    required this.detail,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String line;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Insets.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppColors.goldSoft, size: 28),
          const SizedBox(height: Insets.md),
          Text(title, style: AppType.titleMd),
          const SizedBox(height: 2),
          Text(
            line,
            style: AppType.bodySm.copyWith(fontSize: 12, color: AppColors.mist),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            detail,
            style: AppType.label.copyWith(color: AppColors.mistFaint),
          ),
        ],
      ),
    );
  }
}

class _SurahRow extends StatelessWidget {
  const _SurahRow({required this.surah});

  final Surah surah;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      onTap: () => context.push(Routes.quranSurah(surah.number)),
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
            ),
            child: Text(
              '${surah.number}',
              style: AppType.numeral.copyWith(
                fontSize: 13,
                color: AppColors.gold,
              ),
            ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(surah.name, style: AppType.titleSm),
                Text(
                  '${surah.meaning} · ${surah.ayahCount} ayahs · '
                  '${surah.isMakki ? 'Makkah' : 'Madinah'}',
                  style: AppType.bodySm.copyWith(
                    fontSize: 12,
                    color: AppColors.mistFaint,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Insets.sm),
          Text(
            surah.arabicName,
            textDirection: TextDirection.rtl,
            style: AppType.arabic(
              20,
              height: 1.2,
            ).copyWith(color: AppColors.goldSoft),
          ),
        ],
      ),
    );
  }
}
