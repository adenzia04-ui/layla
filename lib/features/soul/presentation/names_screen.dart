import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../../mood/domain/mood_comfort.dart';
import '../../tasbih/application/tasbih_controller.dart';
import '../../tasbih/domain/dhikr.dart';
import '../application/name_speaker.dart';
import '../application/names_store.dart';
import '../domain/names_detail.dart';
import '../domain/names_of_allah.dart';
import 'widgets/known_ring.dart';
import 'widgets/name_share_card.dart';

/// One of the Names each day, the ninety-nine beneath it, and the ways into
/// each: hear it, read it, live it, save it, share it, learn it.
class NamesScreen extends ConsumerWidget {
  const NamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DivineName today = NamesOfAllah.forDay(DateTime.now());
    final int number = NamesOfAllah.indexOf(today) + 1;
    final NameDetail detail = kNameDetails[number - 1];
    final Set<int> saved = ref.watch(savedNamesProvider);
    final int known = ref.watch(knownNamesProvider).length;

    return NightScaffold(
      scrollable: true,
      ornamentHeight: 240,
      leading: CircleIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        tooltip: 'Back',
        onPressed: () => context.pop(),
      ),
      actions: <Widget>[
        CircleIconButton(
          icon: Icons.school_outlined,
          tooltip: 'Learn the 99',
          onPressed: () => context.push(Routes.soulNamesQuiz),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.xl),
          Text('Names of Allah', style: AppType.displayLg),
          const SizedBox(height: Insets.sm),
          Text(
            'To Allah belong the most beautiful names, so call on Him by '
            'them. — Al-A\'raf 7:180',
            style: AppType.body.copyWith(color: AppColors.mist),
          ),
          const SizedBox(height: Insets.xl),
          NightCard(
            onTap: () => showNameDetail(context, today),
            borderColor: AppColors.gold.withValues(alpha: 0.45),
            padding: const EdgeInsets.all(Insets.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Text(
                  '$number of 99',
                  textAlign: TextAlign.center,
                  style: AppType.label.copyWith(color: AppColors.goldDim),
                ),
                const SizedBox(height: Insets.md),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    today.arabic,
                    textAlign: TextAlign.center,
                    style: AppType.quran(44).copyWith(
                      color: AppColors.goldSoft,
                      shadows: <Shadow>[
                        Shadow(
                          color: AppColors.gold.withValues(alpha: 0.45),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(today.transliteration, style: AppType.displaySm),
                    const SizedBox(width: Insets.sm),
                    _SpeakButton(arabic: today.arabic),
                  ],
                ),
                const SizedBox(height: Insets.xs),
                Text(
                  today.meaning,
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: AppColors.cream),
                ),
                const SizedBox(height: Insets.lg),
                Text(
                  detail.dua,
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(
                    color: AppColors.goldSoft,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: Insets.md),
                Text(
                  'Tap to read what it means, and how to live it today',
                  textAlign: TextAlign.center,
                  style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          NightCard(
            onTap: () => context.push(Routes.soulNamesQuiz),
            child: Row(
              children: <Widget>[
                KnownRing(known: known),
                const SizedBox(width: Insets.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Learn the 99', style: AppType.titleMd),
                      const SizedBox(height: 2),
                      Text(
                        known == 0
                            ? 'See the Arabic, pick the meaning. Three a day '
                                  'is plenty.'
                            : '$known known so far. ${99 - known} to go.',
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
          ),
          if (saved.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.xl),
            const SectionHeader(label: 'Saved'),
            NightCard(
              padding: const EdgeInsets.symmetric(vertical: Insets.sm),
              child: Column(
                children: <Widget>[
                  for (final int i in saved.toList()..sort())
                    _NameRow(
                      number: i + 1,
                      name: NamesOfAllah.all[i],
                      isToday: NamesOfAllah.all[i] == today,
                      saved: true,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: Insets.xl),
          const SectionHeader(label: 'All ninety-nine'),
          NightCard(
            padding: const EdgeInsets.symmetric(vertical: Insets.sm),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < NamesOfAllah.all.length; i++)
                  _NameRow(
                    number: i + 1,
                    name: NamesOfAllah.all[i],
                    isToday: NamesOfAllah.all[i] == today,
                    saved: saved.contains(i),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}

class _SpeakButton extends ConsumerWidget {
  const _SpeakButton({required this.arabic});

  final String arabic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CircleIconButton(
      icon: Icons.volume_up_rounded,
      tooltip: 'Hear it',
      onPressed: () => ref.read(nameSpeakerProvider).say(arabic),
    );
  }
}

class _NameRow extends StatelessWidget {
  const _NameRow({
    required this.number,
    required this.name,
    required this.isToday,
    required this.saved,
  });

  final int number;
  final DivineName name;
  final bool isToday;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showNameDetail(context, name),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.sm,
        ),
        decoration: isToday
            ? BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.08),
                border: const Border(
                  left: BorderSide(color: AppColors.gold, width: 2),
                ),
              )
            : null,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 26,
              child: Text(
                '$number',
                style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(name.transliteration, style: AppType.titleSm),
                  Text(
                    name.meaning,
                    style: AppType.bodySm.copyWith(color: AppColors.mist),
                  ),
                ],
              ),
            ),
            if (saved) ...<Widget>[
              const Icon(
                Icons.bookmark_rounded,
                size: 14,
                color: AppColors.goldDim,
              ),
              const SizedBox(width: Insets.sm),
            ],
            Text(
              name.arabic,
              textDirection: TextDirection.rtl,
              style: AppType.quran(
                20,
              ).copyWith(color: isToday ? AppColors.goldSoft : AppColors.cream),
            ),
          ],
        ),
      ),
    );
  }
}

/// The name, opened: hear it, what it means, a dua that calls by it, one
/// thing to do today, where the app's verses use it, and the hadith every one
/// of the ninety-nine rests on. Bookmark and share at the top.
Future<void> showNameDetail(BuildContext context, DivineName name) {
  final int index = NamesOfAllah.indexOf(name);
  return showModalBottomSheet<void>(
    context: context,
    // Above the shell's floating bar, not beneath it.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => _NameSheet(index: index),
  );
}

class _NameSheet extends ConsumerWidget {
  const _NameSheet({required this.index});

  final int index;

  DivineName get name => NamesOfAllah.all[index];
  NameDetail get detail => kNameDetails[index];
  int get number => index + 1;

  String get _quran {
    final int? n = detail.mentions;
    if (n == null) {
      return "Known from the Sunnah, and from what the Qur'an describes Allah "
          'doing, rather than as a word in the text.';
    }
    final String where = name.verse == null
        ? '.'
        : n == 1
        ? ', in ${name.verse}.'
        : ', for example in ${name.verse}.';
    return n == 1
        ? "Used as a name once in the Qur'an$where"
        : "Used as a name $n times in the Qur'an$where";
  }

  /// "Ya Shakur" from "Ash-Shakur"; the compound names keep their shape.
  String get _vocative {
    final String t = name.transliteration;
    if (t.startsWith('Dhul')) return 'Ya Dhal-Jalali wal-Ikram';
    if (t.startsWith('Malik')) return 'Ya Malik al-Mulk';
    final RegExpMatch? m = RegExp(r'^A[a-z]{1,2}-').firstMatch(t);
    return 'Ya ${m == null ? t : t.substring(m.end)}';
  }

  /// "يَا شَكُور" from "الشَّكُورُ": drop the article and the shadda it
  /// caused on a sun letter.
  String get _vocativeArabic {
    String a = name.arabic;
    if (a.startsWith('ذُو') || a.startsWith('مَالِك')) return 'يَا $a';
    if (a.startsWith('ال')) {
      a = a.substring(2);
      if (a.length > 1 && a[1] == 'ّ') a = a[0] + a.substring(2);
    }
    return 'يَا $a';
  }

  /// The verses in the Mood deck that carry this name.
  List<Comfort> get _met {
    final String bare = _strip(name.arabic.replaceFirst(RegExp('^ال'), ''));
    if (bare.length < 3) return const <Comfort>[];
    final Map<String, Comfort> found = <String, Comfort>{};
    for (final Mood mood in Mood.values) {
      for (final Comfort c in MoodComfort.forMood(mood)) {
        final bool byVerse =
            name.verse != null &&
            c.reference.toLowerCase() == name.verse!.toLowerCase();
        final bool byWord =
            c.arabic != null && _strip(c.arabic!).contains(bare);
        if (byVerse || byWord) found[c.id] = c;
      }
    }
    return found.values.take(3).toList();
  }

  static String _strip(String s) => s.replaceAll(RegExp('[ً-ْٰـ]'), '');

  void _repeat(BuildContext context, WidgetRef ref) {
    ref.read(tasbihProvider.notifier)
      ..setMode(TasbihMode.manual)
      ..setDhikr(
        Dhikr(
          name: _vocative,
          arabic: _vocativeArabic,
          meaning: name.meaning,
          defaultTarget: 33,
        ),
      );
    Navigator.of(context).pop();
    context.push(Routes.tasbihCounter);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double bottom = MediaQuery.paddingOf(context).bottom;
    final bool saved = ref.watch(savedNamesProvider).contains(index);
    final List<Comfort> met = _met;

    return Container(
      margin: const EdgeInsets.fromLTRB(Insets.sm, 0, Insets.sm, Insets.sm),
      padding: EdgeInsets.fromLTRB(
        Insets.xl,
        Insets.md,
        Insets.xl,
        Insets.xl + bottom,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[AppColors.navyElevated, AppColors.navy],
        ),
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mistFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            Row(
              children: <Widget>[
                Text(
                  '$number of 99',
                  style: AppType.label.copyWith(color: AppColors.goldDim),
                ),
                const Spacer(),
                CircleIconButton(
                  icon: saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  tooltip: saved ? 'Saved' : 'Save',
                  foreground: saved ? AppColors.gold : null,
                  onPressed: () =>
                      ref.read(savedNamesProvider.notifier).toggle(index),
                ),
                const SizedBox(width: Insets.sm),
                CircleIconButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: 'Share',
                  onPressed: () => shareName(
                    context,
                    name: name,
                    number: number,
                    detail: detail,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            Center(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  name.arabic,
                  textAlign: TextAlign.center,
                  style: AppType.quran(48).copyWith(
                    color: AppColors.goldSoft,
                    shadows: <Shadow>[
                      Shadow(
                        color: AppColors.gold.withValues(alpha: 0.45),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(name.transliteration, style: AppType.displayMd),
                const SizedBox(width: Insets.sm),
                _SpeakButton(arabic: name.arabic),
              ],
            ),
            const SizedBox(height: Insets.xs),
            Center(
              child: Text(
                name.meaning,
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: AppColors.gold),
              ),
            ),
            const SizedBox(height: Insets.xl),
            const SectionHeader(label: 'What it means'),
            Text(
              detail.about,
              style: AppType.body.copyWith(color: AppColors.cream),
            ),
            const SizedBox(height: Insets.xl),
            const SectionHeader(label: 'Call on Him by it'),
            Text(
              detail.dua,
              style: AppType.body.copyWith(
                color: AppColors.goldSoft,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: Insets.xl),
            const SectionHeader(label: 'Live it today'),
            Text(
              detail.practice,
              style: AppType.body.copyWith(color: AppColors.cream),
            ),
            const SizedBox(height: Insets.md),
            GhostButton(
              label: 'Repeat $_vocative, 33 times',
              icon: Icons.circle_outlined,
              onPressed: () => _repeat(context, ref),
            ),
            if (met.isNotEmpty) ...<Widget>[
              const SizedBox(height: Insets.xl),
              const SectionHeader(label: "Where you've met it"),
              for (final Comfort c in met) _MetVerse(comfort: c),
            ],
            const SizedBox(height: Insets.xl),
            const SectionHeader(label: "In the Qur'an"),
            Text(_quran, style: AppType.body.copyWith(color: AppColors.cream)),
            const SizedBox(height: Insets.xl),
            const SectionHeader(label: 'Hadith'),
            Text(
              '“$kNamesHadith”',
              style: AppType.body.copyWith(color: AppColors.cream),
            ),
            const SizedBox(height: Insets.xs),
            Text(
              kNamesHadithSource,
              style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// One verse from the Mood deck that carries the name, and the way back to
/// the deck it lives in.
class _MetVerse extends StatelessWidget {
  const _MetVerse({required this.comfort});

  final Comfort comfort;

  @override
  Widget build(BuildContext context) {
    final List<Mood> moods = MoodComfort.moodsFor(comfort);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: moods.isEmpty
            ? null
            : () {
                Navigator.of(context).pop();
                context.push(Routes.moodDeck(moods.first.name));
              },
        child: Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            color: AppColors.midnight.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: AppColors.navyLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (comfort.arabic != null)
                Text(
                  comfort.arabic!,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: AppType.quran(18).copyWith(color: AppColors.goldSoft),
                ),
              const SizedBox(height: Insets.xs),
              Text(
                comfort.english,
                style: AppType.bodySm.copyWith(color: AppColors.cream),
              ),
              const SizedBox(height: Insets.xs),
              Row(
                children: <Widget>[
                  Text(
                    comfort.reference,
                    style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                  ),
                  const Spacer(),
                  if (moods.isNotEmpty)
                    Text(
                      'Open in Mood · ${moods.first.label}',
                      style: AppType.bodySm.copyWith(color: AppColors.gold),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
