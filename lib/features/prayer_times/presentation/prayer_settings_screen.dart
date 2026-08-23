import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/prefs_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../application/prayer_times_controller.dart';
import '../data/prayer_settings_repository.dart';
import '../domain/prayer.dart';
import '../domain/prayer_settings.dart';

class PrayerSettingsScreen extends ConsumerWidget {
  const PrayerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrayerSettings settings = ref.watch(prayerSettingsProvider);
    final PrayerSettingsRepository repo =
        ref.watch(prayerSettingsRepositoryProvider);

    return NightScaffold(
      scrollable: true,
      ornamentHeight: 180,
      title: 'Prayer settings',
      leading: Padding(
        padding: const EdgeInsets.all(Insets.sm),
        child: CircleIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onPressed: () => context.pop(),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.xxxl),
          const SectionHeader(label: 'Calculation method'),
          NightCard(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: RadioGroup<CalcMethod>(
              groupValue: settings.method,
              onChanged: (CalcMethod? value) {
                if (value != null) repo.setMethod(settings, value);
              },
              child: Column(
                children: <Widget>[
                  for (final CalcMethod method in CalcMethod.values)
                    RadioListTile<CalcMethod>(
                      value: method,
                      activeColor: AppColors.gold,
                      contentPadding: EdgeInsets.zero,
                      title: Text(method.label, style: AppType.titleSm),
                      subtitle: Text(
                        method.description,
                        style: AppType.bodySm.copyWith(
                          fontSize: 11,
                          color: AppColors.mistFaint,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.xl),
          const SectionHeader(label: 'Asr calculation'),
          NightCard(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: RadioGroup<MadhabOption>(
              groupValue: settings.madhab,
              onChanged: (MadhabOption? value) {
                if (value != null) repo.setMadhab(settings, value);
              },
              child: Column(
                children: <Widget>[
                  for (final MadhabOption madhab in MadhabOption.values)
                    RadioListTile<MadhabOption>(
                      value: madhab,
                      activeColor: AppColors.gold,
                      contentPadding: EdgeInsets.zero,
                      title: Text(madhab.label, style: AppType.titleSm),
                      subtitle: Text(
                        madhab.description,
                        style: AppType.bodySm.copyWith(
                          fontSize: 11,
                          color: AppColors.mistFaint,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.xl),
          const SectionHeader(label: 'Manual adjustments'),
          Text(
            'Nudge a prayer by a few minutes to match your local mosque.',
            style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
          ),
          const SizedBox(height: Insets.md),
          NightCard(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.sm,
            ),
            child: Column(
              children: <Widget>[
                for (final PrayerId id in PrayerId.obligatory)
                  _AdjustmentRow(
                    id: id,
                    minutes: settings.adjustmentFor(id),
                    onChanged: (int value) =>
                        repo.setAdjustment(settings, id, value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          const SectionHeader(label: 'Display'),
          NightCard(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: Column(
              children: <Widget>[
                SwitchListTile.adaptive(
                  value: settings.use24hClock,
                  onChanged: (bool value) {
                    repo.setUse24hClock(settings, use24h: value);
                    ref.read(prefsProvider).setUse24hClock(value);
                  },
                  activeThumbColor: AppColors.gold,
                  contentPadding: EdgeInsets.zero,
                  title: Text('24-hour clock', style: AppType.titleSm),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}

class _AdjustmentRow extends StatelessWidget {
  const _AdjustmentRow({
    required this.id,
    required this.minutes,
    required this.onChanged,
  });

  final PrayerId id;
  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Insets.xs),
      child: Row(
        children: <Widget>[
          Icon(id.icon, size: 17, color: AppColors.mist),
          const SizedBox(width: Insets.md),
          Expanded(child: Text(id.label, style: AppType.titleSm)),
          IconButton(
            onPressed: minutes <= -30 ? null : () => onChanged(minutes - 1),
            iconSize: 20,
            color: AppColors.mist,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 52,
            child: Text(
              minutes == 0
                  ? '0'
                  : '${minutes > 0 ? '+' : ''}$minutes',
              textAlign: TextAlign.center,
              style: AppType.numeral.copyWith(
                color: minutes == 0 ? AppColors.mist : AppColors.gold,
              ),
            ),
          ),
          IconButton(
            onPressed: minutes >= 30 ? null : () => onChanged(minutes + 1),
            iconSize: 20,
            color: AppColors.mist,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      ),
    );
  }
}
