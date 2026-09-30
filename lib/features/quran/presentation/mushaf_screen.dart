import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/audio/recitation_handler.dart';
import '../../../core/audio/recitation_player.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../application/quran_player.dart';
import '../application/quran_prefs.dart';
import '../application/quran_word.dart';
import '../data/mushaf_pages.dart';
import '../domain/ayah_words.dart';
import '../domain/mushaf_glyphs.dart';
import '../domain/quran_data.dart';
import 'widgets/ayah_card.dart';
import 'widgets/mushaf_frame.dart';
import 'widgets/page_glow.dart';
import 'widgets/quran_player_bar.dart';

/// The mushaf, page by page, as the Madinah edition prints it.
///
/// Every page is bundled, so it opens with no signal. Pages turn the way a
/// book does — swipe left for the next page, as the text runs right to
/// left, and the page lifts and lays down as it goes. Around each page the
/// mushaf's own furniture: the surah name and the juz in the head, the
/// page number in the foot, an ornamental border. Nothing is re-typed: what
/// is on screen is the printed page.
///
/// Opened for one surah, the book is held to that surah's pages, so a
/// swipe past the end of Al-Baqarah does not land in Ali 'Imran.
///
/// While a reciter reads, the ayah is washed in gold on the page and the
/// word being spoken glows and glides along the line; the book turns to
/// the next page as the voice reaches it. A touch on any word starts the
/// recitation from that ayah. Each swipe turns exactly one page.
class MushafScreen extends ConsumerStatefulWidget {
  const MushafScreen({super.key, this.surah, this.page});

  /// Held to this surah's pages when given.
  final int? surah;

  /// Opens at this page; otherwise where the mushaf was left.
  final int? page;

  @override
  ConsumerState<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends ConsumerState<MushafScreen> {
  PageController? _controller;
  final ValueNotifier<int> _anchor = ValueNotifier<int>(0);
  int _page = 1;
  int _first = 1;
  int _last = Quran.pageCount;

  /// Cream glyphs on the night sky, instead of ink on paper.
  bool _night = false;

  int get _count => _last - _first + 1;

  void _setUp(Quran q) {
    if (_controller != null) return;
    if (widget.surah case final int s when s >= 1 && s <= 114) {
      _first = q.surah(s).firstPage;
      _last = q.surah(s).lastPage;
    }
    final int saved = ref.read(lastPageProvider);
    final int wanted = widget.page ?? (widget.surah == null ? saved : _first);
    _page = wanted.clamp(_first, _last);
    _controller = PageController(initialPage: _page - _first);
    _anchor.value = _page - _first;
    MushafPages.instance.warmAround(_page, first: _first, last: _last);
  }

  @override
  void dispose() {
    _anchor.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _onPage(int index) {
    _anchor.value = index;
    setState(() => _page = _first + index);
    unawaited(ref.read(lastPageProvider.notifier).set(_page));
    MushafPages.instance.warmAround(_page, first: _first, last: _last);
  }

  Future<void> _jump(Quran q) async {
    final int? target = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.navy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
      builder: (BuildContext context) =>
          _JumpSheet(quran: q, current: _page, first: _first, last: _last),
    );
    if (target != null && mounted) {
      _controller?.jumpToPage(target.clamp(_first, _last) - _first);
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
        _setUp(q);
        final List<Surah> here = q.surahsOnPage(_page);
        final List<Ayah> ayahs = q.onPage(_page);
        final String names = here.map((Surah s) => s.name).join(' · ');
        final int juz = q.juzOfPage(_page);
        final Surah? held = widget.surah == null
            ? null
            : q.surah(widget.surah!);

        // Turn the page with the voice, within the pages this book holds.
        ref.listen<(int, int)?>(
          spokenWordProvider.select(
            (SpokenWord? w) => w == null ? null : (w.surah, w.ayah),
          ),
          ((int, int)? _, (int, int)? at) {
            if (at == null) return;
            final List<Ayah> list = q.ayahsOf(at.$1);
            if (at.$2 < 1 || at.$2 > list.length) return;
            final int page = list[at.$2 - 1].page;
            if (page == _page || page < _first || page > _last) return;
            unawaited(
              _controller?.animateToPage(
                page - _first,
                duration: const Duration(milliseconds: 460),
                curve: Curves.easeInOutCubic,
              ),
            );
          },
        );

        // The bar follows whichever surah on this page is sounding; with
        // nothing playing, the surah the book is held to, or the first.
        final NowPlaying? np = ref.watch(nowPlayingProvider).valueOrNull;
        final int? sounding = np != null && np.owner.startsWith('quran:')
            ? int.tryParse(np.owner.substring(6))
            : null;
        final int barSurah =
            sounding != null && here.any((Surah s) => s.number == sounding)
            ? sounding
            : held?.number ?? (ayahs.isEmpty ? 1 : ayahs.first.surah);

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
                            held?.name ?? names,
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
                      held == null
                          ? 'Page $_page of ${Quran.pageCount} · Juz $juz'
                          : 'Page $_page · ${_page - _first + 1} of $_count in '
                                '${held.name} · Juz $juz',
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
                onPressed: () {
                  unawaited(HapticFeedback.selectionClick());
                  setState(() => _night = !_night);
                },
              ),
            ],
          ),
          body: NotificationListener<ScrollStartNotification>(
            // A swipe is measured from the page under the finger when it
            // lands, so a second swipe mid-turn still moves just one page.
            onNotification: (ScrollStartNotification n) {
              if (n.dragDetails != null && (_controller?.hasClients ?? false)) {
                _anchor.value = (_controller!.page ?? 0).round();
              }
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              // Right to left: the next page comes from the left, like the book.
              reverse: true,
              // No rubber-band at the covers: a book does not stretch past
              // its last page, and the turn animation under a bounce read as
              // the page tearing loose.
              physics: _OnePagePhysics(
                anchor: _anchor,
                parent: const ClampingScrollPhysics(),
              ),
              itemCount: _count,
              onPageChanged: _onPage,
              itemBuilder: (BuildContext context, int i) {
                final int number = _first + i;
                return _Turning(
                  controller: _controller!,
                  index: i,
                  child: _Page(
                    number: number,
                    night: _night,
                    quran: q,
                    surahName: q
                        .surahsOnPage(number)
                        .map((Surah s) => s.arabicName)
                        .join(' · '),
                    juzName: 'الجزء ${juzOrdinals[q.juzOfPage(number) - 1]}',
                    onTapAyah: (int surah, int ayah) {
                      unawaited(HapticFeedback.lightImpact());
                      unawaited(
                        playSurah(ref, quran: q, surah: surah, ayah: ayah),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: ayahs.isEmpty
              ? null
              : QuranPlayerBar(
                  quran: q,
                  surah: barSurah,
                  fromAyah: ayahs.first.surah == barSurah
                      ? ayahs.first.number
                      : 1,
                ),
        );
      },
    );
  }
}

/// A page that lifts as it leaves and lays flat as it arrives.
///
/// A turn of the book, not a slide of a carousel: the page rotates a little
/// about its spine-side edge, in perspective, and darkens as it lifts. Kept
/// gentle — the point is that the eye reads it as paper, not that it draws
/// attention to itself.
class _Turning extends StatelessWidget {
  const _Turning({
    required this.controller,
    required this.index,
    required this.child,
  });

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? _) {
        double delta = 0;
        if (controller.hasClients && controller.position.haveDimensions) {
          delta = (controller.page ?? index.toDouble()) - index;
        }
        final double t = delta.clamp(-1.0, 1.0);
        // The spine is on the right (the book opens to the left), so a page
        // on its way out pivots about its right edge.
        // A shallow perspective and a modest angle: deeper values made the
        // near edge balloon towards the viewer mid-turn. The page also
        // shrinks a touch as it lifts, so it never looks larger in motion
        // than at rest.
        final double s = 1 - t.abs() * 0.06;
        final Matrix4 m = Matrix4.identity()
          ..setEntry(3, 2, 0.0005)
          ..rotateY(t * math.pi * 0.22)
          ..scaleByDouble(s, s, 1, 1);
        return Transform(
          alignment: t > 0 ? Alignment.centerLeft : Alignment.centerRight,
          transform: m,
          child: Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              child,
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: t.abs() * 0.38),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: child,
    );
  }
}

/// One page per swipe, like a book.
///
/// The stock page physics let a hard flick — or a second swipe while the
/// page was still settling — carry the book two or three pages on, and its
/// spring snapped the page down quickly. Here a swipe goes exactly one page
/// from the page the finger landed on, whatever its speed, and the page
/// settles on a critically damped spring: no bounce, no rush.
class _OnePagePhysics extends ScrollPhysics {
  const _OnePagePhysics({required this.anchor, super.parent});

  /// The page under the finger when the swipe began.
  final ValueNotifier<int> anchor;

  @override
  _OnePagePhysics applyTo(ScrollPhysics? ancestor) =>
      _OnePagePhysics(anchor: anchor, parent: buildParent(ancestor));

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 1, stiffness: 90, damping: 19);

  @override
  bool get allowImplicitScrolling => false;

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final double width = position.viewportDimension;
    if (width <= 0) return super.createBallisticSimulation(position, velocity);
    final double here = position.pixels / width;
    final Tolerance tolerance = toleranceFor(position);
    int target;
    if (velocity.abs() > tolerance.velocity) {
      target = velocity > 0 ? anchor.value + 1 : anchor.value - 1;
    } else {
      target = here.round();
    }
    target = target.clamp(anchor.value - 1, anchor.value + 1);
    final double to = (target * width).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((to - position.pixels).abs() < 0.5) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      to,
      velocity,
      tolerance: tolerance,
    );
  }
}

class _Page extends ConsumerWidget {
  const _Page({
    required this.number,
    required this.night,
    required this.quran,
    required this.surahName,
    required this.juzName,
    required this.onTapAyah,
  });

  final int number;
  final bool night;
  final Quran quran;
  final String surahName;
  final String juzName;
  final void Function(int surah, int ayah) onTapAyah;

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
  Widget build(BuildContext context, WidgetRef ref) {
    // This page repaints only when the word on *this* page changes.
    final SpokenWord? spoken = ref.watch(
      spokenWordProvider.select((SpokenWord? w) {
        if (w == null) return null;
        final List<Ayah> list = quran.ayahsOf(w.surah);
        if (w.ayah < 1 || w.ayah > list.length) return null;
        return list[w.ayah - 1].page == number ? w : null;
      }),
    );
    final MushafGlyphs? glyphs = ref.watch(glyphsProvider).valueOrNull;
    final PageGlyphs? boxes = glyphs?.page(number);

    Widget image = _PageImage(number: number, night: night);
    if (night) {
      image = ColorFiltered(
        colorFilter: const ColorFilter.matrix(_invert),
        child: image,
      );
    }
    final Color ink = night ? AppColors.cream : const Color(0xFF1B2A44);
    final TextStyle head = AppType.arabic(15, height: 1.2).copyWith(color: ink);

    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Insets.sm, 0, Insets.sm, Insets.sm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: night ? const Color(0xFF0A1428) : MushafFrame.paper,
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
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Column(
                children: <Widget>[
                  // The head, as the mushaf prints it: juz on the right,
                  // surah on the left.
                  Directionality(
                    textDirection: TextDirection.rtl,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Row(
                        children: <Widget>[
                          Text(juzName, style: head),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              surahName.contains('·')
                                  ? surahName
                                  : 'سُورَةُ $surahName',
                              style: head,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: MushafFrame(
                      night: night,
                      band: 16,
                      child: boxes == null || glyphs == null
                          ? image
                          : _Sheet(
                              image: image,
                              imageSize: glyphs.imageSize,
                              boxes: boxes,
                              spoken: spoken,
                              quran: quran,
                              night: night,
                              onTapAyah: onTapAyah,
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AyahCard.arabicNumeral(number),
                    style: AppType.arabic(16, height: 1.1).copyWith(color: ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Go to a page or a surah, within the pages this mushaf is held to.
class _JumpSheet extends StatefulWidget {
  const _JumpSheet({
    required this.quran,
    required this.current,
    required this.first,
    required this.last,
  });

  final Quran quran;
  final int current;
  final int first;
  final int last;

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
    if (p == null || p < widget.first || p > widget.last) return;
    Navigator.of(context).pop(p);
  }

  @override
  Widget build(BuildContext context) {
    final List<Surah> surahs = widget.quran.surahs
        .where(
          (Surah s) => s.lastPage >= widget.first && s.firstPage <= widget.last,
        )
        .toList();
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
                        hintText: 'Page ${widget.first}–${widget.last}',
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
                      minimumSize: const Size(72, 48),
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
                itemCount: surahs.length,
                itemBuilder: (BuildContext context, int i) {
                  final Surah s = surahs[i];
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
                    onTap: () => Navigator.of(
                      context,
                    ).pop(s.firstPage.clamp(widget.first, widget.last)),
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

/// The page image with the light on it and a touch on any word.
class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.image,
    required this.imageSize,
    required this.boxes,
    required this.spoken,
    required this.quran,
    required this.night,
    required this.onTapAyah,
  });

  final Widget image;
  final Size imageSize;
  final PageGlyphs boxes;
  final SpokenWord? spoken;
  final Quran quran;
  final bool night;
  final void Function(int surah, int ayah) onTapAyah;

  /// Where `BoxFit.contain` puts the image inside [size].
  Rect _fitted(Size size) {
    final double scale = math.min(
      size.width / imageSize.width,
      size.height / imageSize.height,
    );
    final double w = imageSize.width * scale;
    final double h = imageSize.height * scale;
    return Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final Size size = Size(c.maxWidth, c.maxHeight);
        final Rect fitted = _fitted(size);

        List<Glyph> ayahGlyphs = const <Glyph>[];
        int wordPosition = 0;
        if (spoken != null) {
          ayahGlyphs = boxes.ofAyah(spoken!.ayahKey);
          if (spoken!.word > 0) {
            final Ayah a = quran.ayahsOf(spoken!.surah)[spoken!.ayah - 1];
            wordPosition = wordToken(ayahTokens(a.arabic), spoken!.word) + 1;
          }
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (TapUpDetails d) {
            final Offset p = d.localPosition;
            if (!fitted.contains(p)) return;
            final Offset inImage = Offset(
              (p.dx - fitted.left) / fitted.width * imageSize.width,
              (p.dy - fitted.top) / fitted.height * imageSize.height,
            );
            final Glyph? g = boxes.hit(inImage);
            if (g != null) onTapAyah(g.surah, g.ayah);
          },
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              image,
              PageGlow(
                ayahGlyphs: ayahGlyphs,
                wordPosition: wordPosition,
                imageSize: imageSize,
                fitted: fitted,
                night: night,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One printed page. Bundled on the iPhone; on Android fetched the first
/// time it is opened and kept, with a quiet spinner meanwhile and a way to
/// try again when there is no signal.
class _PageImage extends StatefulWidget {
  const _PageImage({required this.number, required this.night});

  final int number;
  final bool night;

  @override
  State<_PageImage> createState() => _PageImageState();
}

class _PageImageState extends State<_PageImage> {
  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    final Color ink = widget.night ? AppColors.cream : const Color(0xFF1B2A44);
    return Image(
      key: ValueKey<int>(_attempt),
      image: MushafPages.instance.pageImage(widget.number),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      frameBuilder: (_, Widget child, int? frame, bool sync) =>
          frame == null && !sync
          ? Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ink.withValues(alpha: 0.5),
                ),
              ),
            )
          : child,
      errorBuilder: (_, __, ___) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Insets.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.wifi_off_rounded, color: ink.withValues(alpha: 0.6)),
              const SizedBox(height: Insets.sm),
              Text(
                'Page ${widget.number} needs a connection the first time it '
                'opens. To read with no signal, download all the pages from '
                'Downloads on the Qur’an screen.',
                textAlign: TextAlign.center,
                style: AppType.bodySm.copyWith(color: ink),
              ),
              TextButton(
                onPressed: () => setState(() => _attempt++),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
