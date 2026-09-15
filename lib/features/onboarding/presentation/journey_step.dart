import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/journey_answers.dart';

/// One question in the first-run journey.
///
/// Deliberately a small interface. The journey will keep growing — every new
/// screen someone sketches is another one of these — and the cost of adding
/// one should be writing a class and putting it in a list, not touching the
/// host, the progress bar, or the navigation.
@immutable
abstract class JourneyStep {
  const JourneyStep();

  /// The question, in the app's own voice.
  String title(JourneyAnswers a);

  /// Whether the answer given so far is enough to move on.
  bool answered(JourneyAnswers a);

  /// Whether this step applies at all.
  ///
  /// Asking for Screen Time from someone who has just said they do not want
  /// their apps paused is worse than not asking: it reads as the app ignoring
  /// the answer it was given a moment ago.
  bool shows(JourneyAnswers a) => true;

  /// Steps whose options commit the moment they are tapped carry no footer
  /// button — a Next button under a single-choice list is a second tap asking
  /// people to confirm what they already said.
  bool get advancesOnTap => false;

  /// Footer label, for steps that have one.
  String label(JourneyAnswers a) => 'Next';

  /// Whether the step paints its own full-bleed layout instead of the
  /// standard title-then-body column.
  bool get bare => false;

  Widget body(BuildContext context, WidgetRef ref, JourneyAnswers a);
}
