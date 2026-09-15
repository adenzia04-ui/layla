import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../application/journey_controller.dart';
import '../../domain/journey_answers.dart';
import '../journey_step.dart';
import '../widgets/journey_chrome.dart';

/// The close: a promise, signed and held.
///
/// The signature is never uploaded and never leaves the device — it is not
/// evidence of anything and no one else will read it. It is here because
/// writing your own name with your finger takes a second longer than tapping,
/// and that second is the entire point.
class PledgeStep extends JourneyStep {
  const PledgeStep();

  @override
  String title(JourneyAnswers a) => '';

  @override
  bool answered(JourneyAnswers a) => a.pledged;

  @override
  bool get bare => true;

  @override
  Widget body(BuildContext context, WidgetRef ref, JourneyAnswers a) =>
      _Pledge(answers: a);
}

class _Pledge extends ConsumerStatefulWidget {
  const _Pledge({required this.answers});

  final JourneyAnswers answers;

  @override
  ConsumerState<_Pledge> createState() => _PledgeState();
}

class _PledgeState extends ConsumerState<_Pledge>
    with SingleTickerProviderStateMixin {
  final List<List<Offset>> _strokes = <List<Offset>>[];

  late final AnimationController _hold =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..addStatusListener((AnimationStatus s) {
        if (s == AnimationStatus.completed) {
          HapticFeedback.heavyImpact();
          ref.read(journeyProvider.notifier).setPledged(true);
        }
      });

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  bool get _signed => _strokes.any((List<Offset> s) => s.length > 4);

  @override
  Widget build(BuildContext context) {
    final String who = widget.answers.name.trim().isEmpty
        ? 'I'
        : widget.answers.name.trim();
    final bool done = widget.answers.pledged;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Allah SWT said:',
          style: AppType.titleSm.copyWith(color: AppColors.gold),
        ),
        const SizedBox(height: Insets.sm),
        Text(
          '“If he comes to Me walking, I go to him running.”',
          style: AppType.displaySm.copyWith(color: AppColors.cream),
        ),
        const SizedBox(height: 4),
        Text(
          'Sahih al-Bukhari 7405',
          style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
        ),
        const SizedBox(height: Insets.xxxl),
        AccentedText(<String>[
          'I, ',
          who,
          ', promise to do what is in my power to draw nearer to Allah and '
              'to keep my prayers.',
        ], style: AppType.body),
        const SizedBox(height: Insets.xl),

        // The signing surface.
        Stack(
          children: <Widget>[
            Container(
              height: 170,
              decoration: BoxDecoration(
                color: AppColors.navy,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _signed ? AppColors.gold : AppColors.navyLine,
                ),
              ),
              child: GestureDetector(
                onPanStart: (DragStartDetails d) =>
                    setState(() => _strokes.add(<Offset>[d.localPosition])),
                onPanUpdate: (DragUpdateDetails d) =>
                    setState(() => _strokes.last.add(d.localPosition)),
                child: CustomPaint(
                  painter: _SignaturePainter(strokes: _strokes),
                  size: Size.infinite,
                ),
              ),
            ),
            if (_strokes.isNotEmpty)
              Positioned(
                right: 6,
                bottom: 6,
                child: IconButton(
                  tooltip: 'Undo the last stroke',
                  onPressed: () => setState(_strokes.removeLast),
                  icon: const Icon(
                    Icons.undo_rounded,
                    color: AppColors.mistFaint,
                  ),
                ),
              ),
            if (_strokes.isEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Text(
                      'Sign here',
                      style: AppType.bodySm.copyWith(
                        color: AppColors.mistFaint,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: Insets.xl),

        // Hold, not tap. A promise that can be made by a stray thumb is not
        // one, and the fill gives the second back as something to watch.
        // Listener, not GestureDetector.
        //
        // onTapDown/onTapUp look right and are wrong for a hold: once the
        // thumb travels past kTouchSlop (18 logical pixels) the tap recogniser
        // gives up and fires onTapCancel, so the fill rewound mid-promise with
        // nothing on screen to say why. Eighteen pixels is not much to ask of
        // a finger held still for 1.4 seconds, and it is nothing at all if the
        // page beneath can scroll. Raw pointer events have no such opinion —
        // the fill runs for as long as the finger is actually down.
        Listener(
          onPointerDown: (_) {
            if (!_signed || done) return;
            HapticFeedback.selectionClick();
            _hold.forward();
          },
          onPointerUp: (_) => _hold.reverse(),
          onPointerCancel: (_) => _hold.reverse(),
          child: AnimatedBuilder(
            animation: _hold,
            builder: (BuildContext context, _) {
              final double t = done ? 1 : _hold.value;
              return Container(
                height: 56,
                // No alignment here, deliberately.
                //
                // A Container with an alignment expands to its own constraints
                // but hands its child *loose* ones, so the Stack shrink-wrapped
                // to the label and Positioned.fill filled only that: the sweep
                // ran the width of the words instead of the width of the
                // button. The Stack centres the label itself, so the alignment
                // was never needed here — it was only ever costing the fill its
                // width.
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.navyElevated,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: done || _signed
                        ? AppColors.gold
                        : AppColors.navyLine,
                  ),
                  // The glow builds with the fill, so the button looks like it
                  // is charging rather than merely changing colour.
                  boxShadow: t == 0
                      ? null
                      : <BoxShadow>[
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.34 * t),
                            blurRadius: 22 * t,
                            spreadRadius: 1,
                          ),
                        ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: t,
                        // goldDim on navyElevated was two dark colours a shade
                        // apart — the fill was moving the whole time, there
                        // was just nothing to see. Bright, and lit from the
                        // leading edge so the sweep reads as motion.
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                AppColors.goldDim,
                                AppColors.gold,
                                AppColors.goldSoft,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      done
                          ? 'Promise made'
                          : _signed
                          ? 'Hold to make your promise'
                          : 'Sign above first',
                      style: AppType.button.copyWith(
                        // Cream on gold is barely legible, so the label darkens
                        // as the fill reaches it and is midnight by the time
                        // the gold is under it.
                        color: !_signed && !done
                            ? AppColors.mistFaint
                            : Color.lerp(
                                AppColors.cream,
                                AppColors.midnight,
                                Curves.easeIn.transform(t),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter({required this.strokes});

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint ink = Paint()
      ..color = AppColors.cream
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final List<Offset> stroke in strokes) {
      if (stroke.length < 2) {
        if (stroke.length == 1) {
          canvas.drawCircle(
            stroke.first,
            1.3,
            Paint()..color = AppColors.cream,
          );
        }
        continue;
      }
      final Path p = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (int i = 1; i < stroke.length; i++) {
        p.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(p, ink);
    }
  }

  // The list is mutated in place rather than replaced, so a field comparison
  // would never see a change. Every setState here means new ink.
  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
