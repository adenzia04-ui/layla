import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/layla_mark.dart';
import '../../application/journey_controller.dart';
import '../../domain/journey_answers.dart';
import '../journey_step.dart';
import '../widgets/journey_chrome.dart';

/// The opening. No question, no progress to make — just who is speaking.
class WelcomeStep extends JourneyStep {
  const WelcomeStep();

  @override
  String title(JourneyAnswers a) => '';

  @override
  bool answered(JourneyAnswers a) => true;

  @override
  bool get bare => true;

  @override
  String label(JourneyAnswers a) => "Let's begin";

  @override
  Widget body(BuildContext context, WidgetRef ref, JourneyAnswers a) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const LaylaMark(height: 150),
        const SizedBox(height: Insets.xxxl),
        Text(
          'Assalamu alaikum.',
          style: AppType.displayLg.copyWith(color: AppColors.cream),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Insets.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
          child: Text(
            'I am Layla Pro. A few questions, and I will know how best to keep '
            'you company through the day.',
            style: AppType.body.copyWith(color: AppColors.mist),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class NameStep extends JourneyStep {
  const NameStep();

  @override
  String title(JourneyAnswers a) => 'What should I call you?';

  @override
  bool answered(JourneyAnswers a) => a.name.trim().isNotEmpty;

  @override
  Widget body(BuildContext context, WidgetRef ref, JourneyAnswers a) =>
      _NameField(initial: a.name);
}

class _NameField extends ConsumerStatefulWidget {
  const _NameField({required this.initial});

  final String initial;

  @override
  ConsumerState<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends ConsumerState<_NameField> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.done,
      style: AppType.displayMd.copyWith(color: AppColors.cream),
      cursorColor: AppColors.gold,
      decoration: InputDecoration(
        hintText: 'Your name',
        hintStyle: AppType.displayMd.copyWith(color: AppColors.mistFaint),
        filled: true,
        fillColor: AppColors.navy,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Insets.xl,
          vertical: Insets.xl,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.navyLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
      ),
      onChanged: (String v) => ref.read(journeyProvider.notifier).setName(v),
    );
  }
}

class GenderStep extends JourneyStep {
  const GenderStep();

  @override
  String title(JourneyAnswers a) => 'Brother or sister?';

  @override
  bool answered(JourneyAnswers a) => a.gender != null && a.avatar != null;

  @override
  Widget body(BuildContext context, WidgetRef ref, JourneyAnswers a) {
    final JourneyController c = ref.read(journeyProvider.notifier);
    final ({String key, IconData icon, String verse, String ref})? chosen =
        JourneyAvatars.byKey(a.avatar);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'A handful of screens change their wording. Nothing else does.',
          style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
        ),
        const SizedBox(height: Insets.lg),
        for (final String g in <String>['brother', 'sister']) ...<Widget>[
          ChoiceTile(
            label: g == 'brother' ? 'Brother' : 'Sister',
            selected: a.gender == g,
            onTap: () => c.setGender(g),
          ),
          const SizedBox(height: Insets.sm),
        ],
        const SizedBox(height: Insets.lg),
        Text(
          'Pick a token',
          style: AppType.label.copyWith(color: AppColors.mistFaint),
        ),
        const SizedBox(height: Insets.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            for (final ({String key, IconData icon, String verse, String ref}) v
                in JourneyAvatars.all)
              GestureDetector(
                onTap: () => c.setAvatar(v.key),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 62,
                  width: 62,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.navy,
                    border: Border.all(
                      color: a.avatar == v.key
                          ? AppColors.gold
                          : AppColors.navyLine,
                      width: a.avatar == v.key ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    v.icon,
                    size: 28,
                    color: a.avatar == v.key ? AppColors.gold : AppColors.mist,
                  ),
                ),
              ),
          ],
        ),
        if (chosen != null) ...<Widget>[
          const SizedBox(height: Insets.xl),
          Text(
            '“${chosen.verse}”',
            style: AppType.body.copyWith(color: AppColors.mist),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            chosen.ref,
            style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Age, on a keypad rather than a wheel.
///
/// A wheel starting at some arbitrary default is a wheel most people leave
/// where it stands, and an age nobody actually gave is worse than no age.
class AgeStep extends JourneyStep {
  const AgeStep();

  @override
  String title(JourneyAnswers a) => 'How old are you?';

  @override
  bool answered(JourneyAnswers a) => (a.age ?? 0) >= 5 && (a.age ?? 0) <= 120;

  @override
  Widget body(BuildContext context, WidgetRef ref, JourneyAnswers a) {
    final JourneyController c = ref.read(journeyProvider.notifier);
    final String shown = a.age == null ? '' : '${a.age}';

    void press(String key) {
      HapticFeedback.selectionClick();
      if (key == '<') {
        final String next = shown.isEmpty
            ? ''
            : shown.substring(0, shown.length - 1);
        c.setAge(next.isEmpty ? 0 : int.parse(next));
        return;
      }
      if (shown.length >= 3) return;
      c.setAge(int.parse('$shown$key'));
    }

    return Column(
      children: <Widget>[
        SizedBox(
          height: 84,
          child: Center(
            child: Text(
              shown.isEmpty ? '—' : shown,
              style: AppType.clock.copyWith(
                fontSize: 60,
                color: shown.isEmpty ? AppColors.mistFaint : AppColors.gold,
              ),
            ),
          ),
        ),
        const SizedBox(height: Insets.lg),
        for (final List<String> row in const <List<String>>[
          <String>['1', '2', '3'],
          <String>['4', '5', '6'],
          <String>['7', '8', '9'],
          <String>['', '0', '<'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: Row(
              children: <Widget>[
                for (final String k in row)
                  Expanded(
                    child: k.isEmpty
                        ? const SizedBox(height: 58)
                        : Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Insets.xs,
                            ),
                            child: _Key(label: k, onTap: () => press(k)),
                          ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.navyLine),
        ),
        child: label == '<'
            ? const Icon(
                Icons.backspace_outlined,
                color: AppColors.mist,
                size: 20,
              )
            : Text(
                label,
                style: AppType.titleLg.copyWith(color: AppColors.cream),
              ),
      ),
    );
  }
}

/// A yes/no question that commits on tap.
class BinaryStep extends JourneyStep {
  const BinaryStep({
    required this.question,
    required this.read,
    required this.write,
    this.yes = 'Yes',
    this.no = 'No',
    this.note,
  });

  final String question;
  final bool? Function(JourneyAnswers) read;
  final void Function(JourneyController, bool) write;
  final String yes;
  final String no;
  final String? note;

  @override
  String title(JourneyAnswers a) => question;

  @override
  bool answered(JourneyAnswers a) => read(a) != null;

  @override
  bool get advancesOnTap => true;

  @override
  Widget body(BuildContext context, WidgetRef ref, JourneyAnswers a) {
    final JourneyController c = ref.read(journeyProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (note != null) ...<Widget>[
          Text(
            note!,
            style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
          ),
          const SizedBox(height: Insets.lg),
        ],
        ChoiceTile(
          label: yes,
          selected: read(a) == true,
          onTap: () => write(c, true),
        ),
        const SizedBox(height: Insets.sm),
        ChoiceTile(
          label: no,
          selected: read(a) == false,
          onTap: () => write(c, false),
        ),
      ],
    );
  }
}

/// How many of the five they manage now.
class PrayersADayStep extends JourneyStep {
  const PrayersADayStep();

  @override
  String title(JourneyAnswers a) => 'How many prayers do you keep in a day?';

  @override
  bool answered(JourneyAnswers a) => a.prayersADay != null;

  @override
  Widget body(BuildContext context, WidgetRef ref, JourneyAnswers a) {
    final JourneyController c = ref.read(journeyProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Answer honestly rather than hopefully. I will set a first target '
          'you can actually clear.',
          style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
        ),
        const SizedBox(height: Insets.xl),
        Row(
          children: <Widget>[
            for (int n = 0; n <= 5; n++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () => c.setPrayersADay(n),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 62,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: a.prayersADay == n
                            ? AppColors.navyElevated
                            : AppColors.navy,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: a.prayersADay == n
                              ? AppColors.gold
                              : AppColors.navyLine,
                          width: a.prayersADay == n ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        '$n',
                        style: AppType.titleLg.copyWith(
                          color: a.prayersADay == n
                              ? AppColors.gold
                              : AppColors.mist,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
