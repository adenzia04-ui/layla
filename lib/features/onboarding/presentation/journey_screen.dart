import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/services/prefs_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/night_hero.dart';
import '../../../core/widgets/ornament_backdrop.dart';
import '../application/journey_controller.dart';
import '../domain/journey_answers.dart';
import 'journey_step.dart';
import 'steps/basic_steps.dart';
import 'steps/permission_steps.dart';
import 'steps/pledge_step.dart';
import 'steps/reflection_steps.dart';
import 'widgets/journey_chrome.dart';

/// The order of the journey.
///
/// A plain list on purpose: this is the one place the shape of the first run
/// is decided, and reordering it, or dropping a question that turns out not to
/// earn its screen, should be moving a line.
const List<JourneyStep> journeySteps = <JourneyStep>[
  WelcomeStep(),
  NameStep(),
  GenderStep(),
  AgeStep(),
  BinaryStep(
    question: 'What is your journey with Islam?',
    yes: 'I reverted to Islam',
    no: 'Born Muslim',
    read: _readRevert,
    write: _writeRevert,
  ),
  PrayersADayStep(),
  BinaryStep(
    question: 'Do you struggle to pray on time?',
    read: _readOnTime,
    write: _writeOnTime,
  ),
  BinaryStep(
    question: 'Have you ever said "I will pray later", and then forgotten?',
    read: _readForget,
    write: _writeForget,
  ),
  RemindersStep(),
  BinaryStep(
    question: 'Do you struggle to wake for Fajr?',
    read: _readFajr,
    write: _writeFajr,
  ),
  PhoneHoursStep(),
  ReflectionStep(),
  PauseAppsStep(),
  ScreenTimeStep(),
  BinaryStep(
    question: 'Shall I check your prayer mat when you confirm a prayer?',
    note:
        'A photo of your mat, judged on your phone. It is never uploaded '
        'and never leaves the device.',
    yes: 'Yes, keep me honest',
    no: 'Not for now',
    read: _readMat,
    write: _writeMat,
  ),
  PledgeStep(),
];

// Torn off as top-level functions so the step list can stay `const`. A closure
// is not a constant, and the list being constant is what keeps the journey
// from rebuilding every step on every keystroke.
bool? _readRevert(JourneyAnswers a) => a.revert;
void _writeRevert(JourneyController c, bool v) => c.setRevert(v);
bool? _readOnTime(JourneyAnswers a) => a.strugglesOnTime;
void _writeOnTime(JourneyController c, bool v) => c.setStrugglesOnTime(v);
bool? _readForget(JourneyAnswers a) => a.forgetsAfterDelaying;
void _writeForget(JourneyController c, bool v) => c.setForgetsAfterDelaying(v);
bool? _readFajr(JourneyAnswers a) => a.strugglesWithFajr;
void _writeFajr(JourneyController c, bool v) => c.setStrugglesWithFajr(v);
bool? _readMat(JourneyAnswers a) => a.wantsMatScan;
void _writeMat(JourneyController c, bool v) => c.setWantsMatScan(v);

/// Walks the first-run questions.
class JourneyScreen extends ConsumerStatefulWidget {
  const JourneyScreen({super.key});

  @override
  ConsumerState<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends ConsumerState<JourneyScreen> {
  int _index = 0;

  /// Guards the auto-advance so a rebuild between the answer and the move
  /// cannot fire it twice and skip a question.
  bool _moving = false;

  JourneyStep get _step => journeySteps[_index];

  /// The steps that apply, given what has been answered so far.
  ///
  /// Recomputed rather than cached: answering "no" to pausing apps removes the
  /// Screen Time step from the journey, and the progress bar should show that
  /// the journey just got shorter.
  List<JourneyStep> _visible(JourneyAnswers a) =>
      journeySteps.where((JourneyStep s) => s.shows(a)).toList();

  /// The index of the next applicable step, or -1 at the end.
  int _seek(int from, int direction, JourneyAnswers a) {
    int i = from + direction;
    while (i >= 0 && i < journeySteps.length) {
      if (journeySteps[i].shows(a)) return i;
      i += direction;
    }
    return -1;
  }

  Future<void> _next() async {
    final JourneyAnswers answers = ref.read(journeyProvider);

    // The button on the reminders step says "Allow reminders", so it has to
    // actually ask before it moves on. iOS shows its prompt once per install;
    // moving past without asking would spend that one chance on nothing.
    if (_step is RemindersStep && answers.remindersAllowed == null) {
      await askForReminders(ref);
      if (!mounted) return;
    }

    final int next = _seek(_index, 1, ref.read(journeyProvider));
    if (next == -1) {
      await ref.read(prefsProvider).setOnboardingComplete(true);
      if (mounted) context.go(Routes.welcome);
      return;
    }
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    // unawaited because this is an async method: the lint fires here where it
    // would not in the plain void handlers elsewhere in the app.
    unawaited(HapticFeedback.selectionClick());
    setState(() => _index = next);
  }

  void _back() {
    final int prev = _seek(_index, -1, ref.read(journeyProvider));
    if (prev == -1) return;
    FocusScope.of(context).unfocus();
    setState(() => _index = prev);
  }

  @override
  Widget build(BuildContext context) {
    final JourneyAnswers answers = ref.watch(journeyProvider);

    // Steps that commit on tap move themselves along, after a beat long enough
    // for the tick to be seen. Without the pause the screen changes under the
    // finger and it reads as a misfire.
    ref.listen<JourneyAnswers>(journeyProvider, (JourneyAnswers? _, __) {
      if (!_step.advancesOnTap || _moving) return;
      if (!_step.answered(ref.read(journeyProvider))) return;
      _moving = true;
      Future<void>.delayed(const Duration(milliseconds: 260), () {
        if (!mounted) return;
        _moving = false;
        unawaited(_next());
      });
    });

    final bool ready = _step.answered(answers);

    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const NightHero(starOpacity: 0.55, skylineOpacity: 0),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: OrnamentBackdrop(height: 220, opacity: 0.10),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Insets.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const SizedBox(height: Insets.md),
                  Row(
                    children: <Widget>[
                      SizedBox(
                        width: 40,
                        child: _seek(_index, -1, answers) == -1
                            ? null
                            : IconButton(
                                onPressed: _back,
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: AppColors.mist,
                                ),
                              ),
                      ),
                      Expanded(
                        child: Builder(
                          builder: (BuildContext context) {
                            final List<JourneyStep> shown = _visible(answers);
                            final int at = shown.indexOf(_step);
                            return JourneyProgress(
                              value: (at + 1) / shown.length,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: Insets.xxl),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder: (Widget child, Animation<double> t) =>
                          FadeTransition(
                            opacity: t,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.04),
                                end: Offset.zero,
                              ).animate(t),
                              child: child,
                            ),
                          ),
                      child: SingleChildScrollView(
                        key: ValueKey<int>(_index),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            if (!_step.bare) ...<Widget>[
                              Text(
                                _step.title(answers),
                                style: AppType.displayMd.copyWith(
                                  color: AppColors.cream,
                                ),
                              ),
                              const SizedBox(height: Insets.xxl),
                            ],
                            _step.body(context, ref, answers),
                            const SizedBox(height: Insets.xxl),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (!_step.advancesOnTap)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Insets.lg),
                      child: PrimaryButton(
                        label: _step.label(answers),
                        onPressed: ready ? _next : null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
