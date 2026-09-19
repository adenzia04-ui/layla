import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../application/ayah_player.dart';
import '../application/mood_store.dart';
import '../domain/mood_comfort.dart';
import '../domain/mood_context.dart';
import '../domain/mood_extras.dart';
import 'widgets/comfort_face.dart';
import 'widgets/mood_sheets.dart';
import 'widgets/share_card.dart';
import 'widgets/touch_ripples.dart';
import '../../../core/widgets/platform_icons.dart';

/// Which passages the deck shows.
enum _Source { all, quran, hadith }

/// One mood: a card at a time, and beneath it what else there is to hold.
///
/// The card is still the centre — tap it and it turns to the next passage,
/// one at a time, the way you would be handed these by a person. Below it,
/// in the order someone might want them: a du'a for the feeling, one small
/// thing to do, a story from the Qur'an that speaks to it, and a line to
/// write afterwards. All of it optional; none of it in the way of the card.
class MoodDeckScreen extends ConsumerStatefulWidget {
  const MoodDeckScreen({super.key, required this.mood});

  final Mood mood;

  @override
  ConsumerState<MoodDeckScreen> createState() => _MoodDeckScreenState();
}

class _MoodDeckScreenState extends ConsumerState<MoodDeckScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );
  _Source _source = _Source.all;
  int _index = 0;
  bool _sharing = false;

  /// Which way the card is turning: 1 forward, -1 back.
  int _dir = 1;

  List<Comfort> get _deck {
    final List<Comfort> all = MoodComfort.forMood(widget.mood);
    final List<Comfort> some = switch (_source) {
      _Source.all => all,
      _Source.quran =>
        all.where((Comfort c) => c.source == ComfortSource.quran).toList(),
      _Source.hadith =>
        all.where((Comfort c) => c.source == ComfortSource.hadith).toList(),
    };
    // A mood with nothing of one kind shows everything rather than nothing.
    final List<Comfort> deck = List<Comfort>.of(some.isEmpty ? all : some);
    // Reshuffled every three days, so the first card is not the same card
    // every time the feeling comes back. The seed is the date, so the order
    // holds still within those days and a "2 of 14" means the same thing
    // tomorrow as it did today.
    deck.shuffle(math.Random(_epoch));
    return deck;
  }

  /// Which three-day stretch this is.
  static int get _epoch =>
      DateTime.now().difference(DateTime(2026)).inDays ~/ 3;

  /// After Isha the wash of colour is turned down: many people open this
  /// late, and a bright sky at 1am is the wrong welcome.
  bool get _night {
    final int h = DateTime.now().hour;
    return h >= 20 || h < 5;
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _setSource(_Source s) {
    if (s == _source) return;
    HapticFeedback.selectionClick();
    setState(() {
      _source = s;
      _index = 0;
      _flip.reset();
    });
  }

  /// Turns the card: the right half of it goes on, the left half goes back,
  /// so a card is never a one-time thing — tap left and read it again.
  Future<void> _turn(int dir) async {
    if (_flip.isAnimating) return;
    unawaited(HapticFeedback.lightImpact());
    setState(() => _dir = dir);
    await _flip.forward();
    if (!mounted) return;
    // Dart's % keeps this non-negative, so going back from the first card
    // lands on the last.
    setState(() => _index = (_index + dir) % _deck.length);
    _flip.reset();
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final Comfort comfort = _deck[_index];
      final Uint8List png = await renderShareCard(
        context,
        comfort: comfort,
        mood: widget.mood,
      );
      final Directory dir = await getTemporaryDirectory();
      final File file = File(
        '${dir.path}/layla-${widget.mood.name}-${_index + 1}.png',
      );
      await file.writeAsBytes(png, flush: true);
      if (!mounted) return;
      final RenderBox box = context.findRenderObject()! as RenderBox;
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'image/png')],
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _recite(Comfort c) async {
    final ({int chapter, int verse})? ayah = c.ayah;
    if (ayah == null) return;
    unawaited(HapticFeedback.selectionClick());
    await ref
        .read(ayahPlayerProvider)
        .toggle(
          key: c.id,
          chapter: ayah.chapter,
          verse: ayah.verse,
          // Only the words on the card, not the whole verse.
          excerpt: c.arabic,
          onChange: (String? key) {
            if (mounted) ref.read(recitingProvider.notifier).state = key;
          },
        );
  }

  /// The step is done here, on this page: a tap ticks it, another untick.
  /// It used to open the counter, which pulled the reader away from the
  /// verse they had just been given.
  bool _stepDone = false;

  void _doStep(MoodStep step) {
    HapticFeedback.selectionClick();
    setState(() => _stepDone = !_stepDone);
  }

  @override
  Widget build(BuildContext context) {
    final Mood mood = widget.mood;
    final List<Comfort> deck = _deck;
    final Comfort front = deck[_index];
    final Comfort back = deck[(_index + _dir) % deck.length];
    final bool saved = ref.watch(savedComfortsProvider).contains(front.id);
    final String? reciting = ref.watch(recitingProvider);
    final String? occasion = MoodContext.forReference(front.reference);
    final MoodDua dua = MoodExtras.duaFor(mood);
    final MoodStep step = MoodExtras.stepFor(mood);
    final List<QuranStory> stories = MoodExtras.storiesFor(mood);
    final List<HadithStory> hadith = MoodExtras.hadithFor(widget.mood);

    return TouchRipples(
      color: mood.tone,
      child: Scaffold(
        backgroundColor: AppColors.midnight,
        body: Stack(
          children: <Widget>[
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: const Alignment(0, 0.4),
                    colors: <Color>[
                      mood.tone.withValues(alpha: _night ? 0.14 : 0.28),
                      AppColors.midnight,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: ListView(
                padding: Insets.pageH,
                children: <Widget>[
                  const SizedBox(height: Insets.sm),
                  Row(
                    children: <Widget>[
                      CircleIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        tooltip: 'Back',
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      Icon(mood.icon, size: 18, color: mood.tone),
                      const SizedBox(width: Insets.sm),
                      Text(
                        mood.label.toUpperCase(),
                        style: AppType.label.copyWith(color: mood.tone),
                      ),
                      const Spacer(),
                      CircleIconButton(
                        icon: saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        tooltip: saved ? 'Saved' : 'Save this',
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          ref
                              .read(savedComfortsProvider.notifier)
                              .toggle(front);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: Insets.lg),
                  _SourceToggle(
                    value: _source,
                    tone: mood.tone,
                    onChanged: _setSource,
                  ),
                  const SizedBox(height: Insets.lg),
                  LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) =>
                        GestureDetector(
                          onTapUp: (TapUpDetails d) => _turn(
                            d.localPosition.dx < c.maxWidth / 2 ? -1 : 1,
                          ),
                          behavior: HitTestBehavior.opaque,
                          child: _FlipCard(
                            animation: _flip,
                            direction: _dir,
                            front: ComfortFace(
                              comfort: front,
                              tone: mood.tone,
                              trailing: front.ayah == null
                                  ? null
                                  : _ReciteButton(
                                      playing: reciting == front.id,
                                      tone: mood.tone,
                                      onPressed: () => _recite(front),
                                    ),
                            ),
                            back: ComfortFace(comfort: back, tone: mood.tone),
                          ),
                        ),
                  ),
                  if (occasion != null) ...<Widget>[
                    const SizedBox(height: Insets.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Insets.sm,
                      ),
                      child: Text(
                        occasion,
                        textAlign: TextAlign.center,
                        style: AppType.bodySm.copyWith(
                          color: AppColors.mist,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: Insets.lg),
                  Text(
                    '${_index + 1} of ${deck.length} · Tap right for the next, left to go back',
                    textAlign: TextAlign.center,
                    style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                  ),
                  const SizedBox(height: Insets.lg),
                  GhostButton(
                    label: 'Share to story',
                    icon: kShareIcon,
                    onPressed: _sharing ? null : _share,
                  ),
                  const SizedBox(height: Insets.xxl),
                  const SectionHeader(label: 'A du\'a for this feeling'),
                  _DuaCard(dua: dua, tone: mood.tone),
                  const SizedBox(height: Insets.xl),
                  const SectionHeader(label: 'One small step'),
                  _StepCard(
                    step: step,
                    tone: mood.tone,
                    done: _stepDone,
                    onTap: () => _doStep(step),
                  ),
                  if (stories.isNotEmpty) ...<Widget>[
                    const SizedBox(height: Insets.xl),
                    const SectionHeader(label: 'From the Qur\'an'),
                    for (final QuranStory story in stories)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.md),
                        child: NightCard(
                          onTap: () => showStorySheet(
                            context,
                            story: story,
                            tone: mood.tone,
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.auto_stories_outlined,
                                size: 20,
                                color: mood.tone,
                              ),
                              const SizedBox(width: Insets.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(story.title, style: AppType.titleSm),
                                    const SizedBox(height: 2),
                                    Text(
                                      story.reference,
                                      style: AppType.bodySm.copyWith(
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
                      ),
                  ],
                  if (hadith.isNotEmpty) ...<Widget>[
                    const SizedBox(height: Insets.xl),
                    const SectionHeader(label: 'From the Hadith'),
                    for (final HadithStory h in hadith)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.md),
                        child: NightCard(
                          onTap: () => showHadithSheet(
                            context,
                            hadith: h,
                            tone: mood.tone,
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.format_quote_rounded,
                                size: 20,
                                color: mood.tone,
                              ),
                              const SizedBox(width: Insets.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(h.title, style: AppType.titleSm),
                                    const SizedBox(height: 2),
                                    Text(
                                      h.reference,
                                      style: AppType.bodySm.copyWith(
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
                      ),
                  ],
                  const SizedBox(height: Insets.lg),
                  const SectionHeader(label: 'Afterwards'),
                  NightCard(
                    onTap: () =>
                        showJournalSheet(context, mood: mood, comfort: front),
                    borderColor: mood.tone.withValues(alpha: 0.35),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.edit_note_rounded,
                          size: 22,
                          color: mood.tone,
                        ),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'How do you feel now?',
                                style: AppType.titleSm,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Write a line. It stays on this phone.',
                                style: AppType.bodySm.copyWith(
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
                  const SizedBox(height: Insets.xxxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// All · Qur'an · Hadith.
class _SourceToggle extends StatelessWidget {
  const _SourceToggle({
    required this.value,
    required this.tone,
    required this.onChanged,
  });

  final _Source value;
  final Color tone;
  final ValueChanged<_Source> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.navyLine),
      ),
      child: Row(
        children: <Widget>[
          for (final (_Source s, String label) in const <(_Source, String)>[
            (_Source.all, 'All'),
            (_Source.quran, 'Qur\'an'),
            (_Source.hadith, 'Hadith'),
          ])
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: s == value
                        ? tone.withValues(alpha: 0.22)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.sm),
                    border: Border.all(
                      color: s == value
                          ? tone.withValues(alpha: 0.6)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: AppType.label.copyWith(
                      color: s == value ? AppColors.cream : AppColors.mistFaint,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReciteButton extends StatelessWidget {
  const _ReciteButton({
    required this.playing,
    required this.tone,
    required this.onPressed,
  });

  final bool playing;
  final Color tone;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: playing
                ? tone.withValues(alpha: 0.25)
                : AppColors.navyElevated,
            border: Border.all(color: tone.withValues(alpha: 0.5)),
          ),
          child: Icon(
            playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
            size: 18,
            color: tone,
          ),
        ),
      ),
    );
  }
}

class _DuaCard extends StatelessWidget {
  const _DuaCard({required this.dua, required this.tone});

  final MoodDua dua;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      borderColor: tone.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              dua.arabic,
              textAlign: TextAlign.right,
              style: AppType.quran(22).copyWith(color: AppColors.cream),
            ),
          ),
          const SizedBox(height: Insets.md),
          Text(
            dua.transliteration,
            style: AppType.bodySm.copyWith(
              color: AppColors.goldSoft,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: Insets.md),
          Text(
            dua.meaning,
            style: AppType.body.copyWith(color: AppColors.cream, height: 1.6),
          ),
          const SizedBox(height: Insets.md),
          Text(
            dua.reference,
            style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.tone,
    this.onTap,
    this.done = false,
  });

  final bool done;

  final MoodStep step;
  final Color tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tone.withValues(alpha: 0.16),
              border: Border.all(color: tone.withValues(alpha: 0.5)),
            ),
            alignment: Alignment.center,
            child: done
                ? const Icon(
                    Icons.check_rounded,
                    color: AppColors.emerald,
                    size: 22,
                  )
                : step.count != null
                ? Text(
                    '${step.count}',
                    style: AppType.numeral.copyWith(fontSize: 13, color: tone),
                  )
                : Icon(
                    switch (step.action) {
                      StepAction.pray => Icons.self_improvement_rounded,
                      StepAction.tasbih => Icons.circle_outlined,
                      StepAction.none => Icons.check_rounded,
                    },
                    size: 18,
                    color: tone,
                  ),
          ),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(step.title, style: AppType.titleSm),
                const SizedBox(height: 2),
                Text(
                  step.detail,
                  style: AppType.bodySm.copyWith(
                    color: AppColors.mist,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null) ...<Widget>[
            const SizedBox(width: Insets.sm),
            // Tapping ticks the step off here; nothing opens.
            Icon(
              done ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: done ? AppColors.emerald : AppColors.mistFaint,
            ),
          ],
        ],
      ),
    );
  }
}

/// A card that turns over on its vertical axis: a real 3D rotation with
/// perspective, so the edge thins to a line at the midpoint.
class _FlipCard extends StatelessWidget {
  const _FlipCard({
    required this.animation,
    required this.front,
    required this.back,
    this.direction = 1,
  });

  final Animation<double> animation;

  /// 1 turns to the right, -1 to the left.
  final int direction;
  final Widget front;
  final Widget back;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? _) {
        final double t = Curves.easeInOutCubic.transform(animation.value);
        final double angle = t * math.pi * direction;
        final bool showingBack = angle.abs() > math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: showingBack
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(math.pi),
                  child: back,
                )
              : front,
        );
      },
    );
  }
}
