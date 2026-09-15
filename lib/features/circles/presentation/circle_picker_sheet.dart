import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../friends/domain/friend.dart';
import '../../friends/presentation/widgets/friend_numbers.dart';
import '../application/circles_controller.dart';
import '../domain/circle.dart';
import 'widgets/circle_bar.dart';
import 'widgets/circle_goal_label.dart';

/// "Invite to a circle": your circles, one tap each.
Future<void> showCirclePicker(BuildContext context, Friend friend) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.navy,
    shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
    builder: (BuildContext context) => _CirclePicker(friend: friend),
  );
}

class _CirclePicker extends ConsumerStatefulWidget {
  const _CirclePicker({required this.friend});

  final Friend friend;

  @override
  ConsumerState<_CirclePicker> createState() => _CirclePickerState();
}

class _CirclePickerState extends ConsumerState<_CirclePicker> {
  /// The circle the invitation is going out for, so a second tap waits.
  String? _inviting;

  Future<void> _invite(Circle circle) async {
    if (_inviting != null) return;
    setState(() => _inviting = circle.id);
    await ref
        .read(circleActionsProvider.notifier)
        .invite(widget.friend.uid, circle.id);
    if (!mounted) return;
    // The controller keeps a failure in its state rather than throwing it.
    final Object? error = ref.read(circleActionsProvider).error;
    if (error != null) {
      setState(() => _inviting = null);
      context.showError(error);
      return;
    }
    Navigator.of(context).pop();
    context.showSuccess(
      '${widget.friend.name} is invited to ${circle.name}. They see it when '
      'they next open Layla Pro.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Circle> circles =
        ref.watch(circlesProvider).valueOrNull ?? const <Circle>[];
    final DateTime now = DateTime.now();

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
            Text(
              'Invite ${widget.friend.name}',
              style: AppType.displaySm,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: Insets.xs),
            Text(
              circles.isEmpty
                  ? 'You are not in a circle yet. Start one from the Friends '
                        'screen, then invite people to it.'
                  : 'They get the circle\'s code, and join with one tap.',
              style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
            ),
            const SizedBox(height: Insets.lg),
            for (final Circle circle in circles)
              _CircleRow(
                circle: circle,
                day: circleDayOn(circle, now),
                state: circle.members.contains(widget.friend.uid)
                    ? _RowState.member
                    : circle.members.length >= Circle.maxMembers
                    ? _RowState.full
                    : _inviting == circle.id
                    ? _RowState.sending
                    : _RowState.open,
                onInvite: () => _invite(circle),
              ),
          ],
        ),
      ),
    );
  }
}

enum _RowState { open, sending, member, full }

class _CircleRow extends StatelessWidget {
  const _CircleRow({
    required this.circle,
    required this.day,
    required this.state,
    required this.onInvite,
  });

  final Circle circle;
  final int day;
  final _RowState state;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.navyElevated.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: AppColors.navyLine.withValues(alpha: 0.8)),
        ),
        child: Row(
          children: <Widget>[
            Icon(circle.goal.icon, size: 18, color: AppColors.gold),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    circle.name,
                    style: AppType.titleSm,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${circle.goal.label} · '
                    '${FriendNumbers.dayOf(day, circle.days)}',
                    style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.md),
            switch (state) {
              _RowState.open => TextButton(
                onPressed: onInvite,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: Insets.md,
                    vertical: Insets.sm,
                  ),
                ),
                child: const Text('Invite'),
              ),
              _RowState.sending => const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.gold,
                ),
              ),
              _RowState.member => Text(
                'Already in',
                style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
              ),
              _RowState.full => Text(
                'Full',
                style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
              ),
            },
          ],
        ),
      ),
    );
  }
}
