import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../application/tasbih_controller.dart';
import '../domain/dhikr.dart';
import 'widgets/tasbih_ring.dart';

class TasbihScreen extends ConsumerWidget {
  const TasbihScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TasbihState state = ref.watch(tasbihProvider);
    final TasbihController controller = ref.read(tasbihProvider.notifier);

    return NightScaffold(
      ornamentHeight: 240,
      child: Column(
        children: <Widget>[
          const SizedBox(height: Insets.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Tasbih', style: AppType.displayLg),
                    const SizedBox(height: 2),
                    Text(
                      state.setsCompleted == 0
                          ? 'Tap anywhere in the circle to count'
                          : '${state.setsCompleted} '
                              '${state.setsCompleted == 1 ? 'set' : 'sets'} '
                              'completed in this sitting',
                      style: AppType.bodySm.copyWith(color: AppColors.mist),
                    ),
                  ],
                ),
              ),
              CircleIconButton(
                icon: Icons.tune_rounded,
                tooltip: 'Choose dhikr and target',
                onPressed: () => _openPresets(context, ref),
              ),
            ],
          ),
          const SizedBox(height: Insets.xl),
          _DhikrHeader(dhikr: state.dhikr),
          const Spacer(),
          TasbihRing(
            count: state.count,
            target: state.target,
            progress: state.progress,
            complete: state.isComplete,
            onTap: controller.increment,
          ),
          const SizedBox(height: Insets.xl),
          Text(
            state.isComplete
                ? 'Target reached — keep going or reset'
                : '${state.remaining} to go',
            style: AppType.bodySm.copyWith(
              color: state.isComplete ? AppColors.emerald : AppColors.mist,
            ),
          ),
          const Spacer(),
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
                  label: 'Count',
                  icon: Icons.add_rounded,
                  onPressed: controller.increment,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.xxl),
        ],
      ),
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
            style: AppType.displayMd.copyWith(
              color: AppColors.goldSoft,
              height: 1.6,
            ),
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
                        style:
                            AppType.bodySm.copyWith(color: AppColors.mistFaint),
                      ),
                      secondary: Text(
                        d.arabic,
                        textDirection: TextDirection.rtl,
                        style:
                            AppType.titleMd.copyWith(color: AppColors.goldSoft),
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
