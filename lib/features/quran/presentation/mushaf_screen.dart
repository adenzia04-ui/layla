import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../application/quran_prefs.dart';
import '../domain/quran_data.dart';
import 'widgets/quran_player_bar.dart';

/// The mushaf, page by page, exactly as the Madinah edition prints it.
///
/// Every page is bundled, so it opens with no signal. Pages turn the way a
/// book does — swipe left for the next page, as the text runs right to left.
/// Nothing is re-typed: what is on screen is the printed page, which is the
/// whole point of this view over the reader.
class MushafScreen extends ConsumerStatefulWidget {
  const MushafScreen({super.key, this.page});

  /// Opens at this page; otherwise where the mushaf was left.
  final int? page;

  @override
  ConsumerState<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends ConsumerState<MushafScreen> {
  late final PageController _controller;
  late int _page;

  /// Cream glyphs on the night sky, instead of ink on paper.
  bool _night = false;

  @override
  void initState() {
    super.initState();
    final int saved = ref.read(lastPageProvider);
    final int wanted = widget.page ?? saved;
    _page = wanted.clamp(1, Quran.pageCount);
    _controller = PageController(initialPage: _page - 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPage(int index) {
    setState(() => _page = index + 1);
    unawaited(ref.read(lastPageProvider.notifier).set(_page));
  }

  Future<void> _jump(Quran q) async {
    final int? target = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.navy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
      builder: (BuildContext context) => _JumpSheet(quran: q, current: _page),
    );
    if (target != null && mounted) {
      _controller.jumpToPage(target - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<Quran> quran = ref.watch(quranProvider);

    return quran.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.midnight,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, _) => Scaffold(
        backgroundColor: AppColors.midnight,
        body: Center(
          child: Text(
            '$e',
            style: AppType.bodySm.copyWith(color: AppColors.mist),
          ),
        ),
      ),
      data: (Quran q) {
        final List<Surah> here = q.surahsOnPage(_page);
        final List<Ayah> ayahs = q.onPage(_page);
        final String names = here.map((Surah s) => s.name).join(' · ');
        final int juz = q.juzOfPage(_page);

        return Scaffold(
          backgroundColor: AppColors.midnight,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            leading: BackButton(
              color: AppColors.cream,
              onPressed: () => context.pop(),
            ),
            titleSpacing: 0,
            title: InkWell(
              onTap: () => _jump(q),
              borderRadius: Radii.card,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            names,
                            style: AppType.titleSm,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.expand_more_rounded,
                          size: 18,
                          color: AppColors.mistFaint,
                        ),
                      ],
                    ),
                    Text(
                      'Page $_page of ${Quran.pageCount} · Juz $juz',
                      style: AppType.bodySm.copyWith(
                        fontSize: 11,
                        color: AppColors.mistFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              IconButton(
                tooltip: _night ? 'Paper' : 'Night',
                icon: Icon(
                  _night ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: AppColors.mist,
                ),
                onPressed: () => setState(() => _night = !_night),
              ),
            ],
          ),
          body: PageView.builder(
            controller: _controller,
            // Right to left: the next page comes from the left, like the book.
            reverse: true,
            itemCount: Quran.pageCount,
            onPageChanged: _onPage,
            itemBuilder: (BuildContext context, int i) =>
                _Page(number: i + 1, night: _night),
          ),
          bottomNavigationBar: ayahs.isEmpty
              ? null
              : QuranPlayerBar(
                  quran: q,
                  surah: ayahs.first.surah,
                  fromAyah: ayahs.first.number,
                ),
        );
      },
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.number, required this.night});

  final int number;
  final bool night;

  /// Ink to cream: the page PNGs are black glyphs on a transparent ground,
  /// so inverting the colour channels and leaving alpha alone gives the
  /// same page in the app's own light.
  static const List<double> _invert = <double>[
    -1, 0, 0, 0, 246, //
    0, -1, 0, 0, 241, //
    0, 0, -1, 0, 231, //
    0, 0, 0, 1, 0, //
  ];

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      'assets/quran/pages/$number.png',
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => Center(
        child: Text(
          'Page $number is not bundled.',
          style: AppType.bodySm.copyWith(color: AppColors.mist),
        ),
      ),
    );
    if (night) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_invert),
        child: image,
      );
    }
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.sm, Insets.sm, Insets.sm, 0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: night ? AppColors.midnight : const Color(0xFFFBF7EE),
            borderRadius: BorderRadius.circular(Radii.md),
            boxShadow: night
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.md),
            child: Padding(
              padding: const EdgeInsets.all(Insets.sm),
              child: image,
            ),
          ),
        ),
      ),
    );
  }
}

/// Go to a page or a surah.
class _JumpSheet extends StatefulWidget {
  const _JumpSheet({required this.quran, required this.current});

  final Quran quran;
  final int current;

  @override
  State<_JumpSheet> createState() => _JumpSheetState();
}

class _JumpSheetState extends State<_JumpSheet> {
  final TextEditingController _page = TextEditingController();

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _go() {
    final int? p = int.tryParse(_page.text.trim());
    if (p == null || p < 1 || p > Quran.pageCount) return;
    Navigator.of(context).pop(p);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController controller) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Insets.xl,
                Insets.lg,
                Insets.xl,
                Insets.md,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _page,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onSubmitted: (_) => _go(),
                      style: AppType.body.copyWith(color: AppColors.cream),
                      decoration: InputDecoration(
                        hintText: 'Page 1–${Quran.pageCount}',
                        hintStyle: AppType.bodySm.copyWith(
                          color: AppColors.mistFaint,
                        ),
                        filled: true,
                        fillColor: AppColors.navyElevated,
                        border: const OutlineInputBorder(
                          borderRadius: Radii.card,
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  FilledButton(
                    onPressed: _go,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.midnight,
                    ),
                    child: const Text('Go'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(Insets.xl, 0, Insets.xl, 40),
                itemCount: widget.quran.surahs.length,
                itemBuilder: (BuildContext context, int i) {
                  final Surah s = widget.quran.surahs[i];
                  final bool here =
                      s.firstPage <= widget.current &&
                      widget.current <= s.lastPage;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(
                      '${s.number}',
                      style: AppType.numeral.copyWith(
                        fontSize: 13,
                        color: here ? AppColors.gold : AppColors.mistFaint,
                      ),
                    ),
                    title: Text(
                      s.name,
                      style: AppType.titleSm.copyWith(
                        color: here ? AppColors.gold : AppColors.cream,
                      ),
                    ),
                    subtitle: Text(
                      'Page ${s.firstPage}',
                      style: AppType.bodySm.copyWith(
                        fontSize: 11,
                        color: AppColors.mistFaint,
                      ),
                    ),
                    trailing: Text(
                      s.arabicName,
                      style: AppType.arabic(
                        18,
                        height: 1.2,
                      ).copyWith(color: AppColors.goldSoft),
                    ),
                    onTap: () => Navigator.of(context).pop(s.firstPage),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
