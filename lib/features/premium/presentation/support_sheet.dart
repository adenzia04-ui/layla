import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../application/premium_store.dart';
import '../domain/support_tip.dart';

/// "Support the creator": a one-off gift through Google Play, any amount
/// from the list, as often as someone likes. It unlocks nothing — it is a
/// thank-you to the one person who makes Layla Pro.
Future<void> showSupportSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.navy,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
      builder: (BuildContext context) => const _SupportSheet(),
    );

class _SupportSheet extends ConsumerWidget {
  const _SupportSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PremiumState s = ref.watch(premiumProvider);
    final PremiumStore store = ref.read(premiumProvider.notifier);

    return SafeArea(
      child: Padding(
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
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.navyLine,
                  borderRadius: Radii.chip,
                ),
              ),
            ),
            const SizedBox(height: Insets.lg),
            const Icon(
              Icons.volunteer_activism_rounded,
              color: AppColors.gold,
              size: 32,
            ),
            const SizedBox(height: Insets.md),
            Text(
              'Support the creator',
              textAlign: TextAlign.center,
              style: AppType.titleLg,
            ),
            const SizedBox(height: Insets.sm),
            Text(
              'Layla Pro is made by one person. If it helps your prayer, you '
              'can support the work with a one-off gift. It does not unlock '
              'anything — everything free stays free.',
              textAlign: TextAlign.center,
              style: AppType.bodySm.copyWith(color: AppColors.mist),
            ),
            const SizedBox(height: Insets.xl),
            if (s.thanked != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.all(Insets.lg),
                decoration: BoxDecoration(
                  color: AppColors.emerald.withValues(alpha: 0.12),
                  borderRadius: Radii.card,
                  border: Border.all(
                    color: AppColors.emerald.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  'JazakAllahu khairan. Your ${s.tipPrice(s.thanked!)} went '
                  'through — thank you for supporting Layla Pro.',
                  textAlign: TextAlign.center,
                  style: AppType.bodySm.copyWith(color: AppColors.cream),
                ),
              ),
              const SizedBox(height: Insets.lg),
            ],
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Insets.sm,
              runSpacing: Insets.sm,
              children: <Widget>[
                for (final SupportTip t in SupportTip.values)
                  _Amount(
                    label: s.tipPrice(t),
                    busy: s.busy,
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      unawaited(store.support(t));
                    },
                  ),
              ],
            ),
            if (s.notice != null) ...<Widget>[
              const SizedBox(height: Insets.sm),
              Text(
                s.notice!,
                textAlign: TextAlign.center,
                style: AppType.bodySm.copyWith(color: AppColors.goldSoft),
              ),
            ],
            if (s.error != null) ...<Widget>[
              const SizedBox(height: Insets.md),
              Text(
                s.error!,
                textAlign: TextAlign.center,
                style: AppType.bodySm.copyWith(color: AppColors.rose),
              ),
            ],
            const SizedBox(height: Insets.lg),
            Text(
              'Paid through Google Play. One-off, never repeated.',
              textAlign: TextAlign.center,
              style: AppType.bodySm.copyWith(
                fontSize: 11,
                color: AppColors.mistFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.busy, required this.onTap});

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Material(
        color: AppColors.gold.withValues(alpha: 0.14),
        borderRadius: Radii.card,
        child: InkWell(
          borderRadius: Radii.card,
          onTap: busy ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Insets.lg),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: AppType.titleMd.copyWith(
                color: busy ? AppColors.mistFaint : AppColors.goldSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
