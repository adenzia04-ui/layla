import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/utils/formatters.dart';
import '../../../friends/application/friends_controller.dart';
import '../../../friends/domain/ramadan.dart';
import '../../../friends/presentation/widgets/friend_numbers.dart';

/// Ramadan, under Today's Progress: two switches and a count.
///
/// Nothing here is inferred. Whether someone fasted is not something an app
/// can know from prayer times, so it asks — once a day, with a switch rather
/// than a question, because a switch can be corrected without a dialog.
/// Friends see only what these publish: fasting today, Taraweeh tonight, and
/// the number of fasts.
class RamadanCard extends ConsumerWidget {
  const RamadanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isRamadanProvider)) return const SizedBox.shrink();
    final RamadanRecord record = ref.watch(ramadanProvider);
    final String today = Fmt.dayId(DateTime.now());
    final bool busy = ref.watch(ramadanActionsProvider).isLoading;

    // The controller keeps a failure in its state rather than throwing it;
    // a switch that springs back with no word would look broken.
    Future<void> set(Future<void> Function() action) async {
      await action();
      if (!context.mounted) return;
      final Object? error = ref.read(ramadanActionsProvider).error;
      if (error != null) context.showError(error);
    }

    return Padding(
      padding: const EdgeInsets.only(top: Insets.md),
      child: NightCard(
        padding: const EdgeInsets.fromLTRB(
          Insets.lg,
          Insets.lg,
          Insets.lg,
          Insets.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(
                  Icons.nightlight_round,
                  size: 16,
                  color: AppColors.goldSoft,
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    'RAMADAN',
                    style: AppType.label.copyWith(color: AppColors.gold),
                  ),
                ),
                const SizedBox(width: Insets.sm),
                Text(
                  record.fasts == 0
                      ? 'No fasts counted yet'
                      : '${FriendNumbers.fasts(record.fasts)} so far',
                  style: AppType.bodySm.copyWith(color: AppColors.mist),
                ),
              ],
            ),
            const SizedBox(height: Insets.xs),
            SwitchListTile.adaptive(
              value: record.fastedOnDay(today),
              onChanged: busy
                  ? null
                  : (bool value) => set(
                      () => ref
                          .read(ramadanActionsProvider.notifier)
                          .setFastedToday(value),
                    ),
              activeThumbColor: AppColors.gold,
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(
                Icons.wb_sunny_outlined,
                size: 19,
                color: AppColors.mist,
              ),
              title: Text('I fasted today', style: AppType.titleSm),
            ),
            SwitchListTile.adaptive(
              value: record.taraweehOnDay(today),
              onChanged: busy
                  ? null
                  : (bool value) => set(
                      () => ref
                          .read(ramadanActionsProvider.notifier)
                          .setTaraweehTonight(value),
                    ),
              activeThumbColor: AppColors.gold,
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(
                Icons.bedtime_outlined,
                size: 19,
                color: AppColors.mist,
              ),
              title: Text('Taraweeh tonight', style: AppType.titleSm),
            ),
          ],
        ),
      ),
    );
  }
}
