import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../premium/application/premium_store.dart';
import '../application/tasbih_controller.dart';
import '../application/tasbih_view.dart';
import '../domain/dhikr.dart';
import '../domain/sunnah_routine.dart';
import 'widgets/tasbih_mark.dart';
import 'widgets/tasbih_ring.dart';
import 'widgets/tasbih_strand.dart';
import '../../../core/widgets/layla_mark.dart';

class TasbihScreen extends ConsumerWidget {
  const TasbihScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TasbihState state = ref.watch(tasbihProvider);
    final TasbihController controller = ref.read(tasbihProvider.notifier);
    final bool recite = state.isSunnah && state.dhikr.isRecited;
    final CounterStyle style = ref.watch(counterStyleProvider);
    final bool beads = style.isStrand;

    // A counter, not a flag. Something would have to clear a flag, and whatever
    // cleared it would end up deciding whether the message ever appeared.
    ref.listen<int>(
      tasbihProvider.select((TasbihState s) => s.roundsCompleted),
      (int? was, int now) {
        if (was != null && now > was) {
          _showRoundComplete(context, ref.read(tasbihProvider).routine);
        }
      },
    );

    return Stack(
      children: <Widget>[
        NightScaffold(
          ornamentHeight: 240,
          // Gaps give way before content does — see fitGap for why and by how
          // much. This screen does not scroll, so without it the Count button is
          // what gets clipped.
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double gap = fitGap(context, constraints);
              // The counter scales with the phone: a 264-point ring on a
              // 6.1-inch screen pushed the Count button under the tab bar.
              final double dial = (constraints.maxHeight * 0.36).clamp(
                168.0,
                264.0,
              );
              final Widget column = Column(
                children: <Widget>[
                  SizedBox(height: Insets.lg * gap),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('Tasbih', style: AppType.displayLg),
                            const SizedBox(height: 2),
                            Text(
                              state.isSunnah
                                  ? '${state.sunnahDone} of ${state.routine.total} '
                                        '· ${state.routine.name}'
                                  : state.setsCompleted == 0
                                  ? switch (style) {
                                      CounterStyle.gold ||
                                      CounterStyle.jade ||
                                      CounterStyle.pearl ||
                                      CounterStyle.amethyst ||
                                      CounterStyle.rose ||
                                      CounterStyle.signet =>
                                        'Tap anywhere to move a bead',
                                      CounterStyle.layla =>
                                        'Tap the mark to count',
                                      CounterStyle.ring =>
                                        'Tap anywhere in the circle to count',
                                    }
                                  : '${state.setsCompleted} '
                                        '${state.setsCompleted == 1 ? 'set' : 'sets'} '
                                        'completed in this sitting',
                              style: AppType.bodySm.copyWith(
                                color: AppColors.mist,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CircleIconButton(
                        icon: style.icon,
                        tooltip: 'Choose the counter',
                        onPressed: () => _openStyles(context),
                      ),
                      if (!state.isSunnah) ...<Widget>[
                        const SizedBox(width: Insets.sm),
                        CircleIconButton(
                          icon: Icons.tune_rounded,
                          tooltip: 'Choose dhikr and target',
                          onPressed: () => _openPresets(context, ref),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: Insets.lg * gap),
                  _ModeToggle(mode: state.mode, onChanged: controller.setMode),
                  if (state.isSunnah) ...<Widget>[
                    SizedBox(height: Insets.md * gap),
                    _RoutinePicker(
                      routine: state.routine,
                      onTap: () => _openRoutines(context),
                    ),
                  ],
                  SizedBox(height: Insets.lg * gap),
                  if (!recite) _DhikrHeader(dhikr: state.dhikr),
                  if (state.isSunnah && state.routine.hasStages) ...<Widget>[
                    SizedBox(height: Insets.lg * gap),
                    _StageTrack(routine: state.routine, stage: state.stage),
                  ],
                  // The ring is a fixed circle and wants centring, so it keeps the
                  // Spacers either side. The recitation card is the opposite: it should
                  // take every pixel going, because the passage is the thing this screen
                  // exists to show. Leaving the Spacers in meant they claimed the free
                  // space first, and the card clipped Ayat al-Kursi mid-verse with empty
                  // navy above and below it.
                  if (!recite && !beads) const Spacer(),
                  if (recite)
                    Expanded(
                      child: _FadeEdges(
                        child: SingleChildScrollView(
                          // Inset by the fade band, so nothing sits inside it while the view
                          // is at rest — otherwise the reference line is half-dissolved before
                          // anyone has scrolled at all.
                          padding: const EdgeInsets.only(top: 20, bottom: 12),
                          child: _ReciteCard(
                            dhikr: state.dhikr,
                            count: state.count,
                            target: state.target,
                          ),
                        ),
                      ),
                    )
                  else if (beads)
                    Expanded(
                      child: TasbihStrand(
                        count: state.count,
                        target: state.target,
                        rounds: state.setsCompleted + 1,
                        colours: style.beadColours,
                        signet: style.isSignet,
                        onTap: controller.increment,
                      ),
                    )
                  else if (style == CounterStyle.layla)
                    TasbihMark(
                      size: dial,
                      count: state.count,
                      target: state.target,
                      progress: state.progress,
                      onTap: controller.increment,
                    )
                  else
                    TasbihRing(
                      size: dial,
                      count: state.count,
                      target: state.target,
                      progress: state.progress,
                      complete: state.isComplete,
                      onTap: controller.increment,
                    ),
                  SizedBox(height: (recite ? Insets.md : Insets.xl) * gap),
                  Text(
                    state.isSunnah && state.dhikr.isRecited
                        ? state.target == 1
                              ? 'Recite, then tap Done'
                              : 'Recited ${state.count} of ${state.target}'
                        : state.isSunnah
                        ? '${state.remaining} more ${state.dhikr.name}'
                        : state.isComplete
                        ? 'Target reached — keep going or reset'
                        : '${state.remaining} to go',
                    style: AppType.bodySm.copyWith(
                      color: !state.isSunnah && state.isComplete
                          ? AppColors.emerald
                          : AppColors.mist,
                    ),
                  ),
                  if (!recite && !beads) const Spacer(),
                  if (recite) SizedBox(height: Insets.md * gap),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: GhostButton(
                          label: 'Reset',
                          icon: Icons.refresh_rounded,
                          onPressed: state.count == 0 ? null : controller.reset,
                        ),
                      ),
                      const SizedBox(width: Insets.md),
                      Expanded(
                        child: PrimaryButton(
                          // Just 'Done'. This button sits beside Reset at half width,
                          // and a progress label overflowed it by 88px — the dots on
                          // the card and the line above already say how far along it
                          // is.
                          label: state.isSunnah && state.dhikr.isRecited
                              ? 'Done'
                              : 'Count',
                          icon: state.isSunnah && state.dhikr.isRecited
                              ? Icons.check_rounded
                              : Icons.add_rounded,
                          onPressed: controller.increment,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Insets.xxl * gap),
                ],
              );
              // Recitation and beads take the height they are given; the
              // ring and the mark can still overflow a small phone, so those
              // two scroll rather than clip.
              if (recite || beads) return column;
              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(child: column),
                ),
              );
            },
          ),
        ),
        _SlowDownVeil(visible: state.hurried),
      ],
    );
  }

  /// Shown once the hundred is complete.
  Future<void> _showRoundComplete(
    BuildContext context,
    SunnahRoutine routine,
  ) async {
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.midnight.withValues(alpha: 0.72),
      builder: (BuildContext context) => _RoundCompleteDialog(routine: routine),
    );
  }

  Future<void> _openStyles(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.navy,
      builder: (BuildContext context) => const _StyleSheet(),
    );
  }

  Future<void> _openRoutines(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.navy,
      isScrollControlled: true,
      // Seven routines with their references overrun a phone, so cap the sheet
      // and let it scroll rather than letting the last one fall off the edge.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      builder: (BuildContext context) => const _RoutineSheet(),
    );
  }

  Future<void> _openPresets(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.navy,
      isScrollControlled: true,
      builder: (BuildContext context) => const _PresetSheet(),
    );
  }
}

/// Manual or Sunnah. Two segments rather than a switch, because neither is an
/// "off" state and a switch would imply one is.
/// The message at the end of a full after-prayer round.
class _RoundCompleteDialog extends StatelessWidget {
  const _RoundCompleteDialog({required this.routine});

  final SunnahRoutine routine;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.navy,
      insetPadding: const EdgeInsets.all(Insets.lg),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: AppColors.navyLine),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.12),
                border: Border.all(color: AppColors.goldDim),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.gold,
                size: 30,
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text(
              'Masha\'Allah',
              style: AppType.displayMd.copyWith(color: AppColors.goldSoft),
            ),
            Text(
              '${routine.total} dhikr',
              style: AppType.displaySm.copyWith(color: AppColors.gold),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              'You completed ${routine.name}',
              textAlign: TextAlign.center,
              style: AppType.bodySm.copyWith(color: AppColors.mist),
            ),
            const SizedBox(height: Insets.lg),
            Container(
              padding: const EdgeInsets.all(Insets.lg),
              decoration: BoxDecoration(
                color: AppColors.navyElevated,
                borderRadius: BorderRadius.circular(18),
                border: const Border(
                  left: BorderSide(color: AppColors.gold, width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    routine.narration,
                    style: AppType.bodySm.copyWith(
                      color: AppColors.cream,
                      height: 1.55,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  Text(
                    routine.reference,
                    style: AppType.label.copyWith(color: AppColors.goldSoft),
                  ),
                  if (routine.grading != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      'Graded ${routine.grading}',
                      style: AppType.label.copyWith(color: AppColors.mistFaint),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Done',
                icon: Icons.check_rounded,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The counter faces, previewed rather than described.
class _StyleSheet extends ConsumerWidget {
  const _StyleSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CounterStyle current = ref.watch(counterStyleProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Counter', style: AppType.titleLg),
            const SizedBox(height: 2),
            Text(
              'The count is the same in all of them.',
              style: AppType.bodySm.copyWith(color: AppColors.mist),
            ),
            const SizedBox(height: Insets.lg),
            // Seven faces no longer fit the half-screen a plain bottom sheet
            // gets, and an overflowing Column clips the last one out of reach
            // rather than letting it be scrolled to.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final CounterStyle s in CounterStyle.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.sm),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            if (s.isPremium &&
                                !ref.read(styleUnlockedProvider)) {
                              Navigator.of(context).pop();
                              context.push(Routes.paywall);
                              return;
                            }
                            ref.read(counterStyleProvider.notifier).choose(s);
                            Navigator.of(context).pop();
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            padding: const EdgeInsets.all(Insets.md),
                            decoration: BoxDecoration(
                              color: s == current
                                  ? AppColors.navyElevated
                                  : AppColors.navy,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: s == current
                                    ? AppColors.gold
                                    : AppColors.navyLine,
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                _Swatch(style: s),
                                const SizedBox(width: Insets.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(s.label, style: AppType.titleSm),
                                      Text(
                                        s.blurb,
                                        style: AppType.bodySm.copyWith(
                                          color: AppColors.mistFaint,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (s == current)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.gold,
                                    size: 20,
                                  )
                                else if (s.isPremium &&
                                    ref.watch(styleLocksShownProvider))
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.midnight,
                                      border: Border.all(
                                        color: AppColors.navyLine,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.lock_rounded,
                                      size: 13,
                                      color: AppColors.gold,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small likeness of each counter. Names alone would not tell anyone what
/// "Jade beads" looks like against this navy.
class _Swatch extends StatelessWidget {
  const _Swatch({required this.style});

  final CounterStyle style;

  @override
  Widget build(BuildContext context) {
    if (style == CounterStyle.layla) {
      // The art is cropped to the glyph now, and taller than it is wide —
      // a fixed square would squash it, so the height leads and the box only
      // reserves the column width the other swatches use.
      return const SizedBox(
        height: 34,
        width: 34,
        child: Center(child: LaylaMark(height: 34)),
      );
    }
    if (style == CounterStyle.ring) {
      return const SizedBox(
        height: 34,
        width: 34,
        child: CircularProgressIndicator(
          value: 0.68,
          strokeWidth: 3.5,
          backgroundColor: AppColors.navyLine,
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
        ),
      );
    }
    final List<Color> c = style.beadColours;
    // 38, not 34: three 10px beads with 1px either side come to 36, and the
    // square the other two swatches use is not wide enough for them.
    return SizedBox(
      height: 34,
      width: 38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (int i = 0; i < 3; i++)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.4, -0.5),
                  colors: <Color>[c[0], c[1], c[2]],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final TasbihMode mode;
  final ValueChanged<TasbihMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.navyLine),
      ),
      child: Row(
        children: <Widget>[
          _segment(
            label: 'Manual',
            icon: Icons.tune_rounded,
            selected: mode == TasbihMode.manual,
            onTap: () => onChanged(TasbihMode.manual),
          ),
          _segment(
            label: 'Sunnah',
            icon: Icons.check_circle_outline_rounded,
            selected: mode == TasbihMode.sunnah,
            onTap: () => onChanged(TasbihMode.sunnah),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.gold : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 17,
                  color: selected ? AppColors.midnight : AppColors.mist,
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: AppType.bodySm.copyWith(
                    color: selected ? AppColors.midnight : AppColors.mist,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Where you are in the after-prayer sequence: done, current, still to come.
/// Softens the top and bottom of a scrolling area so text dissolves instead of
/// being sliced off at the boundary.
///
/// A `ShaderMask` in `dstIn` mode, so the gradient's alpha becomes the child's
/// alpha and the fade happens in the compositing. A painted scrim would have
/// meant matching whatever is behind it, and what is behind it here is the
/// night sky with a globe and stars moving through it.
class _FadeEdges extends StatelessWidget {
  const _FadeEdges({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (Rect bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Color(0x00000000),
          Color(0xFF000000),
          Color(0xFF000000),
          Color(0x00000000),
        ],
        // Tight at the top, longer at the foot: that is the edge text is
        // usually running past.
        stops: <double>[0.0, 0.06, 0.88, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

/// A stage that is read rather than counted: the words, how to say them, what
/// they mean, and a confirmation to move on.
class _ReciteCard extends StatelessWidget {
  const _ReciteCard({
    required this.dhikr,
    required this.count,
    required this.target,
  });

  final Dhikr dhikr;
  final int count;
  final int target;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // No card behind it. A navy panel on a navy screen was drawing a box
      // around scripture for no reason — the words carry themselves.
      padding: const EdgeInsets.symmetric(horizontal: Insets.sm),
      child: Column(
        children: <Widget>[
          if (dhikr.source != null) ...<Widget>[
            Text(
              dhikr.source!.toUpperCase(),
              style: AppType.label.copyWith(color: AppColors.gold),
            ),
            const SizedBox(height: Insets.sm),
          ],
          Text(
            dhikr.arabic,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            // Qur'an gets the mushaf face; the dhikr phrases get Amiri. Both
            // beat the system fallback, which has no business setting either.
            style:
                (dhikr.source != null ? AppType.quran(22) : AppType.arabic(24))
                    .copyWith(color: AppColors.goldSoft),
          ),
          const SizedBox(height: Insets.md),
          Text(
            dhikr.spoken,
            textAlign: TextAlign.center,
            style: AppType.bodySm.copyWith(
              color: AppColors.cream,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: Insets.sm),
          Text(
            dhikr.meaning,
            textAlign: TextAlign.center,
            style: AppType.bodySm.copyWith(
              color: dhikr.source != null
                  ? AppColors.mist
                  : AppColors.mistFaint,
              height: 1.5,
            ),
          ),
          if (target > 1) ...<Widget>[
            const SizedBox(height: Insets.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (int i = 0; i < target; i++)
                  Container(
                    width: 9,
                    height: 9,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < count ? AppColors.gold : Colors.transparent,
                      border: Border.all(
                        color: i < count ? AppColors.gold : AppColors.navyLine,
                        width: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The chosen sunnah, and the way to change it.
class _RoutinePicker extends StatelessWidget {
  const _RoutinePicker({required this.routine, required this.onTap});

  final SunnahRoutine routine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.navyLine),
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.menu_book_rounded,
              size: 18,
              color: AppColors.gold,
            ),
            const SizedBox(width: Insets.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(routine.name, style: AppType.titleSm),
                  Text(
                    routine.occasion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                  ),
                ],
              ),
            ),
            Text(
              '${routine.total}',
              style: AppType.titleSm.copyWith(color: AppColors.gold),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: AppColors.mist,
            ),
          ],
        ),
      ),
    );
  }
}

/// Every sunnah on offer, each with the count its narration actually gives.
class _RoutineSheet extends ConsumerWidget {
  const _RoutineSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final SunnahRoutine current = ref.watch(tasbihProvider).routine;
    final TasbihController controller = ref.read(tasbihProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Insets.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Choose a sunnah', style: AppType.titleLg),
            const SizedBox(height: 2),
            Text(
              'Each count is the one its narration gives',
              style: AppType.bodySm.copyWith(color: AppColors.mist),
            ),
            const SizedBox(height: Insets.lg),
            for (final RoutineGroup group in RoutineGroup.values)
              if (SunnahRoutine.inGroup(group).isNotEmpty) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.only(
                    top: Insets.sm,
                    bottom: Insets.sm,
                  ),
                  child: Text(
                    group.label.toUpperCase(),
                    style: AppType.label.copyWith(color: AppColors.gold),
                  ),
                ),
                for (final SunnahRoutine routine in SunnahRoutine.inGroup(
                  group,
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.sm),
                    child: _tile(
                      context,
                      routine: routine,
                      selected: routine.id == current.id,
                      onTap: () {
                        controller.setRoutine(routine);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
              ],
          ],
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required SunnahRoutine routine,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(Insets.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.navyElevated : AppColors.navy,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.gold : AppColors.navyLine,
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
                      Flexible(
                        child: Text(
                          routine.name,
                          style: AppType.titleSm.copyWith(
                            color: selected
                                ? AppColors.goldSoft
                                : AppColors.cream,
                          ),
                        ),
                      ),
                      // Said plainly rather than left out. Everything else here
                      // is Bukhari or Muslim, and quietly listing a hasan
                      // report beside them would imply a standing it does not
                      // have.
                      if (routine.grading != null) ...<Widget>[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.navyLine,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            routine.grading!,
                            style: AppType.label.copyWith(
                              color: AppColors.mist,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    routine.occasion,
                    style: AppType.bodySm.copyWith(color: AppColors.mist),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    routine.hasStages
                        ? routine.stages
                              .map((Dhikr d) => '${d.defaultTarget}')
                              .join(' · ')
                        : '×${routine.total}',
                    style: AppType.label.copyWith(color: AppColors.gold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    routine.virtue,
                    style: AppType.bodySm.copyWith(color: AppColors.mist),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    routine.reference,
                    style: AppType.bodySm.copyWith(
                      color: AppColors.mistFaint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.gold,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _StageTrack extends StatelessWidget {
  const _StageTrack({required this.routine, required this.stage});

  final SunnahRoutine routine;
  final int stage;

  @override
  Widget build(BuildContext context) {
    final List<Widget> row = <Widget>[];
    for (int i = 0; i < routine.stages.length; i++) {
      if (i > 0) {
        row.add(
          Expanded(
            child: Container(
              height: 1,
              margin: EdgeInsets.only(bottom: _compact ? 0 : 22),
              color: i <= stage ? AppColors.gold : AppColors.navyLine,
            ),
          ),
        );
      }
      row.add(_node(i));
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: row);
  }

  /// Labels only fit while there are few stages. Before-sleep protection has
  /// seven, and seven 92px captions overflow a phone by nearly 300px — so past
  /// three the track becomes plain markers and the dhikr card carries the name.
  bool get _compact => routine.stages.length > 3;

  Widget _node(int i) {
    final bool done = i < stage;
    final bool current = i == stage;
    final Dhikr dhikr = routine.stages[i];

    return Column(
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: _compact ? 22 : 30,
          height: _compact ? 22 : 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.gold : Colors.transparent,
            border: Border.all(
              color: done || current ? AppColors.gold : AppColors.navyLine,
              width: 2,
            ),
          ),
          child: done
              ? Icon(
                  Icons.check_rounded,
                  size: _compact ? 13 : 17,
                  color: AppColors.midnight,
                )
              : current
              ? Center(
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold,
                    ),
                  ),
                )
              : null,
        ),
        if (!_compact) ...<Widget>[
          const SizedBox(height: 6),
          SizedBox(
            width: 92,
            child: Text(
              dhikr.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.label.copyWith(
                color: done || current
                    ? AppColors.goldSoft
                    : AppColors.mistFaint,
              ),
            ),
          ),
          Text(
            '${dhikr.defaultTarget}',
            style: AppType.label.copyWith(color: AppColors.mistFaint),
          ),
        ],
      ],
    );
  }
}

class _DhikrHeader extends StatelessWidget {
  const _DhikrHeader({required this.dhikr});

  final Dhikr dhikr;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      padding: const EdgeInsets.symmetric(
        vertical: Insets.lg,
        horizontal: Insets.lg,
      ),
      child: Column(
        children: <Widget>[
          Text(
            dhikr.arabic,
            textAlign: TextAlign.center,
            textDirection: TextDirection.rtl,
            style: AppType.arabic(26).copyWith(color: AppColors.goldSoft),
          ),
          const SizedBox(height: Insets.sm),
          Text(dhikr.name, style: AppType.titleMd),
          const SizedBox(height: 2),
          Text(
            dhikr.meaning,
            textAlign: TextAlign.center,
            style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
          ),
        ],
      ),
    );
  }
}

class _PresetSheet extends ConsumerStatefulWidget {
  const _PresetSheet();

  @override
  ConsumerState<_PresetSheet> createState() => _PresetSheetState();
}

class _PresetSheetState extends ConsumerState<_PresetSheet> {
  static const List<int> _targets = <int>[33, 34, 99, 100, 500, 1000];

  @override
  Widget build(BuildContext context) {
    final TasbihState state = ref.watch(tasbihProvider);
    final TasbihController controller = ref.read(tasbihProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Insets.xl,
          Insets.sm,
          Insets.xl,
          Insets.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Dhikr', style: AppType.displaySm),
            const SizedBox(height: Insets.md),
            RadioGroup<String>(
              groupValue: state.dhikr.name,
              onChanged: (String? value) {
                if (value != null) controller.setDhikr(Dhikr.byName(value));
              },
              child: Column(
                children: <Widget>[
                  for (final Dhikr d in Dhikr.presets)
                    RadioListTile<String>(
                      value: d.name,
                      activeColor: AppColors.gold,
                      contentPadding: EdgeInsets.zero,
                      title: Text(d.name, style: AppType.titleSm),
                      subtitle: Text(
                        '${d.meaning} · usually ${d.defaultTarget}',
                        style: AppType.bodySm.copyWith(
                          color: AppColors.mistFaint,
                        ),
                      ),
                      secondary: Text(
                        d.arabic,
                        textDirection: TextDirection.rtl,
                        style: AppType.arabic(
                          17,
                          height: 1.4,
                        ).copyWith(color: AppColors.goldSoft),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Insets.lg),
            Text('Target', style: AppType.displaySm),
            const SizedBox(height: Insets.md),
            Wrap(
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: <Widget>[
                for (final int t in _targets)
                  AppChip(
                    label: '$t',
                    selected: state.target == t,
                    onTap: () => controller.setTarget(t),
                  ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Custom target',
                    style: AppType.bodySm.copyWith(color: AppColors.mist),
                  ),
                ),
                IconButton(
                  onPressed: () => controller.setTarget(state.target - 1),
                  icon: const Icon(Icons.remove_circle_outline),
                  color: AppColors.mist,
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '${state.target}',
                    textAlign: TextAlign.center,
                    style: AppType.numeral.copyWith(fontSize: 19),
                  ),
                ),
                IconButton(
                  onPressed: () => controller.setTarget(state.target + 1),
                  icon: const Icon(Icons.add_circle_outline),
                  color: AppColors.mist,
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            PrimaryButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// The pause. Comes over the whole screen while the taps outrun the words:
/// a slow-breathing ring, and the Prophet's own line on deliberateness. It
/// lets the taps through — nothing to dismiss — and fades once the pace eases.
class _SlowDownVeil extends StatefulWidget {
  const _SlowDownVeil({required this.visible});

  final bool visible;

  @override
  State<_SlowDownVeil> createState() => _SlowDownVeilState();
}

class _SlowDownVeilState extends State<_SlowDownVeil>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 460),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (Widget child, Animation<double> anim) =>
            FadeTransition(
              opacity: anim,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1).animate(anim),
                child: child,
              ),
            ),
        child: !widget.visible
            ? const SizedBox.shrink(key: ValueKey<String>('calm'))
            : Container(
                key: const ValueKey<String>('hurried'),
                color: AppColors.midnight.withValues(alpha: 0.84),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: Insets.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: _breath,
                      builder: (BuildContext context, Widget? child) {
                        final double t = Curves.easeInOut.transform(
                          _breath.value,
                        );
                        return Container(
                          width: 118 + 22 * t,
                          height: 118 + 22 * t,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.gold.withValues(
                                alpha: 0.35 + 0.4 * t,
                              ),
                              width: 1.5,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.gold.withValues(
                                  alpha: 0.10 + 0.16 * t,
                                ),
                                blurRadius: 44,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: child,
                        );
                      },
                      child: const Icon(
                        Icons.spa_outlined,
                        size: 38,
                        color: AppColors.goldSoft,
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                    Text('Slowly.', style: AppType.displayLg),
                    const SizedBox(height: Insets.sm),
                    Text(
                      'Let each one land before the next.',
                      textAlign: TextAlign.center,
                      style: AppType.body.copyWith(color: AppColors.mist),
                    ),
                    const SizedBox(height: Insets.xxl),
                    Text(
                      'الأَنَاةُ مِنَ اللَّهِ، وَالْعَجَلَةُ مِنَ الشَّيْطَانِ',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: AppType.arabic(
                        26,
                      ).copyWith(color: AppColors.goldSoft),
                    ),
                    const SizedBox(height: Insets.md),
                    Text(
                      'Deliberateness is from Allah, and haste is from Shaytan.',
                      textAlign: TextAlign.center,
                      style: AppType.body.copyWith(color: AppColors.cream),
                    ),
                    const SizedBox(height: Insets.xs),
                    Text(
                      'Jami‘ at-Tirmidhi 2012',
                      style: AppType.bodySm.copyWith(
                        color: AppColors.mistFaint,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
