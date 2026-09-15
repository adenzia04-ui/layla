import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../application/circles_controller.dart';
import '../domain/circle.dart';
import 'widgets/circle_goal_label.dart';

/// The longest name a circle may have; the rules refuse more.
const int kCircleNameMaxLength = 40;

/// "Start a circle": a name and one of three intentions. Hands back the
/// circle once it exists, or null if the sheet was dismissed.
Future<Circle?> showCreateCircleSheet(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<Circle>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.navy,
    shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: const _CreateCircleSheet(),
    ),
  );
}

class _CreateCircleSheet extends ConsumerStatefulWidget {
  const _CreateCircleSheet();

  @override
  ConsumerState<_CreateCircleSheet> createState() => _CreateCircleSheetState();
}

class _CreateCircleSheetState extends ConsumerState<_CreateCircleSheet> {
  final TextEditingController _name = TextEditingController();
  CircleGoal _goal = CircleGoal.fajr;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final String name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    // The controller keeps a failure in its state rather than throwing it.
    final Circle? circle = await ref
        .read(circleActionsProvider.notifier)
        .create(name, _goal);
    if (!mounted) return;
    if (circle == null) {
      setState(() => _busy = false);
      context.showError(
        ref.read(circleActionsProvider).error ??
            'That could not be saved. Try again in a moment.',
      );
      return;
    }
    Navigator.of(context).pop(circle);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          Insets.xl,
          Insets.lg,
          Insets.xl,
          Insets.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'TOGETHER',
              style: AppType.label.copyWith(color: AppColors.gold),
            ),
            const SizedBox(height: Insets.sm),
            Text('Start a circle', style: AppType.displaySm),
            const SizedBox(height: Insets.xs),
            Text(
              'Forty days from today. Everyone you invite sees one shared bar '
              'and each other\'s days — nothing else of yours.',
              style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
            ),
            const SizedBox(height: Insets.xl),
            Text(
              'Name',
              style: AppType.bodySm.copyWith(
                color: AppColors.cream.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              enabled: !_busy,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              inputFormatters: <TextInputFormatter>[
                LengthLimitingTextInputFormatter(kCircleNameMaxLength),
              ],
              onSubmitted: (_) => _create(),
              onChanged: (_) => setState(() {}),
              style: AppType.body.copyWith(color: AppColors.cream),
              decoration: const InputDecoration(
                hintText: 'Fajr with the cousins',
                prefixIcon: Icon(Icons.group_outlined, size: 19),
              ),
            ),
            const SizedBox(height: Insets.xl),
            Text(
              'Kept together',
              style: AppType.bodySm.copyWith(
                color: AppColors.cream.withValues(alpha: 0.72),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Insets.sm),
            // IntrinsicHeight so the three tiles share the tallest one's
            // height: stretched inside a scroll view they would be handed an
            // infinite height, and un-stretched "Fajr on time" on two lines
            // would stand taller than "All five" beside it.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final CircleGoal goal in CircleGoal.values) ...<Widget>[
                    if (goal != CircleGoal.values.first)
                      const SizedBox(width: Insets.sm),
                    Expanded(
                      child: _GoalTile(
                        goal: goal,
                        selected: goal == _goal,
                        onTap: _busy
                            ? null
                            : () => setState(() => _goal = goal),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Insets.sm),
            Text(
              _goal.hint,
              style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
            ),
            const SizedBox(height: Insets.xl),
            PrimaryButton(
              label: 'Start the circle',
              icon: Icons.add_rounded,
              busy: _busy,
              onPressed: _name.text.trim().isEmpty ? null : _create,
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the three intentions, as a tile: a glyph and a name, gold when it
/// is the one chosen.
class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.goal,
    required this.selected,
    required this.onTap,
  });

  final CircleGoal goal;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color ink = selected ? AppColors.gold : AppColors.mist;
    return Semantics(
      button: true,
      selected: selected,
      label: goal.tileLabel,
      child: Material(
        color: selected
            ? AppColors.gold.withValues(alpha: 0.08)
            : AppColors.navyElevated.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(Radii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.sm,
              vertical: Insets.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(
                color: selected
                    ? AppColors.gold
                    : AppColors.navyLine.withValues(alpha: 0.9),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(goal.icon, size: 22, color: ink),
                const SizedBox(height: Insets.sm),
                // Two lines: "Fajr on time" wraps in a third of a small
                // phone at 1.3x, and a cut label is a wrong label.
                Text(
                  goal.tileLabel,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: AppType.titleSm.copyWith(
                    color: selected ? AppColors.cream : AppColors.mist,
                    fontSize: 13,
                    height: 1.2,
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
