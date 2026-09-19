import 'package:flutter_test/flutter_test.dart';
import 'package:noor/features/onboarding/domain/journey_answers.dart';
import 'package:noor/features/onboarding/presentation/journey_screen.dart';
import 'package:noor/features/onboarding/presentation/journey_step.dart';
import 'package:noor/features/onboarding/presentation/steps/permission_steps.dart';
import 'package:noor/features/onboarding/presentation/steps/reflection_steps.dart';

/// A step must never make its own footer button the only way to satisfy it.
///
/// Both of these shipped and deadlocked the journey:
///
/// * `RemindersStep` gated Next on `remindersAllowed`, which is only set by
///   the permission request — and the request runs inside the button that the
///   gate had disabled. The step could not be finished at all.
/// * `PhoneHoursStep` gated Next on `phoneHoursADay` while the dial displayed
///   `phoneHoursADay ?? 3`. Anyone content with the three hours already on
///   screen found Next dead and nothing explaining why.
///
/// The rule both broke: a step may only gate its button on something the
/// person can change *on that screen*. Steps that act on press, or that show a
/// default, must be passable from nothing.
void main() {
  test('steps that act on press are passable from nothing', () {
    const JourneyAnswers nothing = JourneyAnswers();
    for (final JourneyStep step in <JourneyStep>[
      const RemindersStep(),
      const PhoneHoursStep(),
    ]) {
      expect(
        step.answered(nothing),
        isTrue,
        reason:
            '${step.runtimeType} gates Next on its own result — the '
            'journey cannot get past it',
      );
    }
  });

  test('the journey can be walked to the end', () {
    // A person who answers everything the screen offers. Anything still
    // unanswered afterwards is a step with no way through it.
    const JourneyAnswers filled = JourneyAnswers(
      name: 'Aden',
      gender: 'brother',
      avatar: 'palm',
      age: 21,
      revert: false,
      prayersADay: 5,
      strugglesOnTime: true,
      forgetsAfterDelaying: true,
      strugglesWithFajr: true,
      phoneHoursADay: 3,
      wantsMatScan: true,
      wantsAppPause: true,
      remindersAllowed: true,
      pledged: true,
    );

    for (final JourneyStep step in journeySteps) {
      if (!step.shows(filled)) continue;
      expect(
        step.answered(filled),
        isTrue,
        reason: '${step.runtimeType} is unsatisfiable',
      );
    }
  });

  test('declining app pause drops both permission steps', () {
    const JourneyAnswers no = JourneyAnswers(wantsAppPause: false);
    expect(const ScreenTimeStep().shows(no), isFalse);
    expect(const AndroidFocusStep().shows(no), isFalse);
  });

  test('the Apple step and the Android step never both appear', () {
    // One asks for Screen Time, the other for usage access and the overlay,
    // and each is worded for its own platform. An Android phone used to be
    // shown the Apple one — "two taps from Apple" — and then told, when it
    // tapped, that Screen Time is only available on iOS.
    //
    // Tests run on the Dart VM, which is neither platform, so both are false
    // here. What this pins is that neither can ever be true at the same time
    // as the other.
    const JourneyAnswers yes = JourneyAnswers(wantsAppPause: true);
    final bool apple = const ScreenTimeStep().shows(yes);
    final bool android = const AndroidFocusStep().shows(yes);
    expect(apple && android, isFalse);
  });
}
