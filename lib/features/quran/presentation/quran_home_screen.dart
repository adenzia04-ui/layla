import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/edge_fade.dart';
import '../../dua/application/starred_duas.dart';
import '../application/quran_downloads.dart';
import '../application/quran_prefs.dart';
import '../domain/quran_data.dart';
import '../domain/reciters.dart';
import '../domain/surah_search.dart';

/// The Qur'an: the mushaf as printed, or the reader with the words beside
/// their meaning — and the 114 surahs to open either from, by surah, by
/// juz, or in the order they were revealed.
class QuranHomeScreen extends ConsumerStatefulWidget {
  const QuranHomeScreen({super.key});

  @override
  ConsumerState<QuranHomeScreen> createState() => _QuranHomeScreenState();
}

enum _Tab { surahs, juz, revelation }

class _QuranHomeScreenState extends ConsumerState<QuranHomeScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  _Tab _tab = _Tab.surahs;

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
    final Set<int> starred = ref.watch(starredSurahsProvider);
    final Set<String> downloads = ref.watch(downloadsProvider);
    final Reciter reciter = ref.watch(reciterProvider);

    return NightScaffold(
      title: 'Qur’an',
      leading: BackButton(
        color: AppColors.cream,
        onPressed: () => context.pop(),
      ),
      actions: <Widget>[
        IconButton(
          tooltip: 'Downloads',
          icon: const Icon(Icons.offline_pin_outlined, color: AppColors.mist),
          onPressed: () => context.push(Routes.quranDownloads),
        ),
      ],
      showOrnaments: false,
      padding: EdgeInsets.zero,
      extendUnderBar: true,
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
          final Ayah? resume = _resume(q, lastRead);
          final List<Widget> rows = _rows(q, starred, downloads, reciter);

          // The list runs on under the floating bar and fades out as it
          // gets there, the way the home screen's globe does — no hard
          // edge above the glass.
          final double bar = MediaQuery.paddingOf(context).bottom;
          return EdgeFade(
            bottom: bar + 48,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                Insets.page,
                Insets.md,
                Insets.page,
                bar + Insets.xxl,
              ),
              children: <Widget>[
                if (resume != null) ...<Widget>[
                  _Resume(
                    title: 'Continue reading',
                    line:
                        '${q.surah(resume.surah).name} · Ayah ${resume.number}',
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
                        detail: lastPage > 1 ? 'Page $lastPage' : '604 pages',
                        icon: Icons.auto_stories_rounded,
                        onTap: () => context.push(Routes.quranMushaf),
                      ),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: _Mode(
                        title: 'Read & listen',
                        line: 'Arabic, transliteration, translations, tafsir',
                        detail: '${reciters.length} reciters',
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
                _Tabs(
                  current: _tab,
                  onChanged: (_Tab t) => setState(() => _tab = t),
                ),
                const SizedBox(height: Insets.md),
                if (_tab != _Tab.juz) ...<Widget>[
                  TextField(
                    controller: _search,
                    onChanged: (String v) => setState(() => _query = v.trim()),
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
                ],
                ...rows,
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _rows(
    Quran q,
    Set<int> starred,
    Set<String> downloads,
    Reciter reciter,
  ) {
    if (_tab == _Tab.juz) {
      return <Widget>[
        for (final Juz j in q.juzs) ...<Widget>[
          _JuzRow(juz: j, surah: q.surah(j.firstAyah.surah)),
          const SizedBox(height: Insets.sm),
        ],
      ];
    }
    final List<Surah> source = _tab == _Tab.revelation
        ? q.byRevelation
        : q.surahs;
    // Best matches first — a name that starts with what was typed before
    // a meaning that merely contains it — and the tab's own order within
    // each rank. A stable sort keeps that order.
    final List<Surah> matching = <Surah>[
      for (final Surah s in source)
        if (surahMatch(s, _query) > 0) s,
    ];
    if (_query.isNotEmpty) {
      final List<int> rank = <int>[
        for (final Surah s in matching) surahMatch(s, _query),
      ];
      final List<int> order = List<int>.generate(
        matching.length,
        (int i) => i,
      )..sort((int a, int b) => rank[b] != rank[a] ? rank[b] - rank[a] : a - b);
      matching.replaceRange(0, matching.length, <Surah>[
        for (final int i in order) matching[i],
      ]);
    }
    // Starred first, in the tab's own order within each group.
    final List<Surah> ordered = starredFirst(
      matching,
      starred,
      (Surah s) => s.number,
    );
    return <Widget>[
      for (final Surah s in ordered) ...<Widget>[
        _SurahRow(
          surah: s,
          byRevelation: _tab == _Tab.revelation,
          starred: starred.contains(s.number),
          downloaded: downloads.contains(
            SurahDownload(surah: s.number, reciterId: reciter.id).key,
          ),
          onStar: () {
            HapticFeedback.mediumImpact();
            ref.read(starredSurahsProvider.notifier).toggle(s.number);
          },
        ),
        const SizedBox(height: Insets.sm),
      ],
    ];
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

class _Tabs extends StatelessWidget {
  const _Tabs({required this.current, required this.onChanged});

  final _Tab current;
  final ValueChanged<_Tab> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(_Tab t, String label) {
      final bool on = t == current;
      return Expanded(
        child: Material(
          color: on ? AppColors.gold : AppColors.navyElevated,
          borderRadius: Radii.chip,
          child: InkWell(
            borderRadius: Radii.chip,
            onTap: () => onChanged(t),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppType.label.copyWith(
                  color: on ? AppColors.midnight : AppColors.mist,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        chip(_Tab.surahs, 'SURAHS'),
        const SizedBox(width: Insets.sm),
        chip(_Tab.juz, 'JUZ'),
        const SizedBox(width: Insets.sm),
        chip(_Tab.revelation, 'REVEALED'),
      ],
    );
  }
}

class _Resume extends StatelessWidget {
  const _Resume({required this.title, required this.line, required this.onTap});

  final String title;
  final String line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      onTap: onTap,
      borderColor: AppColors.gold.withValues(alpha: 0.5),
      padding: const EdgeInsets.all(Insets.lg),
      child: Row(
        children: <Widget>[
          const Icon(Icons.bookmark_rounded, color: AppColors.gold, size: 22),
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
  const _SurahRow({
    required this.surah,
    required this.byRevelation,
    required this.starred,
    required this.downloaded,
    required this.onStar,
  });

  final Surah surah;
  final bool byRevelation;
  final bool starred;
  final bool downloaded;
  final VoidCallback onStar;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      onTap: () => context.push(Routes.quranSurah(surah.number)),
      borderColor: starred ? AppColors.gold.withValues(alpha: 0.45) : null,
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.md,
        Insets.xs,
        Insets.md,
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
              '${byRevelation ? surah.revelationOrder : surah.number}',
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
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        surah.name,
                        style: AppType.titleSm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (downloaded) ...<Widget>[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.offline_pin_rounded,
                        size: 14,
                        color: AppColors.emerald,
                      ),
                    ],
                  ],
                ),
                Text(
                  byRevelation
                      ? 'Surah ${surah.number} · ${surah.meaning} · '
                            '${surah.isMakki ? 'Makkah' : 'Madinah'}'
                      : '${surah.meaning} · ${surah.ayahCount} ayahs · '
                            '${surah.isMakki ? 'Makkah' : 'Madinah'}',
                  style: AppType.bodySm.copyWith(
                    fontSize: 12,
                    color: AppColors.mistFaint,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          // The mushaf, held to this surah's pages.
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Open in the mushaf',
            icon: const Icon(
              Icons.auto_stories_outlined,
              size: 20,
              color: AppColors.mistFaint,
            ),
            onPressed: () => context.push(Routes.quranMushafOf(surah.number)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: starred ? 'Remove from favourites' : 'Keep at the top',
            icon: Icon(
              starred ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 22,
              color: starred ? AppColors.gold : AppColors.mistFaint,
            ),
            onPressed: onStar,
          ),
        ],
      ),
    );
  }
}

class _JuzRow extends StatelessWidget {
  const _JuzRow({required this.juz, required this.surah});

  final Juz juz;
  final Surah surah;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      onTap: () => context.push(
        '${Routes.quranSurah(juz.firstAyah.surah)}?ayah=${juz.firstAyah.number}',
      ),
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.md,
        Insets.xs,
        Insets.md,
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
              '${juz.number}',
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
                Text('Juz ${juz.number}', style: AppType.titleSm),
                Text(
                  'From ${surah.name} ${juz.firstAyah.number} · '
                  'p. ${juz.firstPage}',
                  style: AppType.bodySm.copyWith(
                    fontSize: 12,
                    color: AppColors.mistFaint,
                  ),
                ),
              ],
            ),
          ),
          Text(
            juz.arabicName,
            textDirection: TextDirection.rtl,
            style: AppType.arabic(
              17,
              height: 1.2,
            ).copyWith(color: AppColors.goldSoft),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Open in the mushaf',
            icon: const Icon(
              Icons.auto_stories_outlined,
              size: 20,
              color: AppColors.mistFaint,
            ),
            onPressed: () =>
                context.push('${Routes.quranMushaf}?page=${juz.firstPage}'),
          ),
        ],
      ),
    );
  }
}
