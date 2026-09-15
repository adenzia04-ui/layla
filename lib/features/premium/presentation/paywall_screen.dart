import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/platform_features.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/layla_mark.dart';
import '../application/charity_fund.dart';
import '../application/premium_store.dart';
import '../domain/premium_plan.dart';

/// Layla Pro Premium: what it unlocks, three ways to pay, and the way back
/// after a reinstall.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  PremiumPlan _plan = PremiumPlan.yearly;

  @override
  Widget build(BuildContext context) {
    final PremiumState premium = ref.watch(premiumProvider);

    ref.listen<PremiumState>(premiumProvider, (
      PremiumState? was,
      PremiumState now,
    ) {
      if (now.isPro && !(was?.isPro ?? false) && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Premium is on. Thank you.')),
        );
        Navigator.of(context).maybePop();
      }
    });

    return NightScaffold(
      scrollable: true,
      ornamentHeight: 260,
      leading: CircleIconButton(
        icon: Icons.close_rounded,
        tooltip: 'Close',
        onPressed: () => context.pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: Insets.xl),
          const Center(child: LaylaMark(height: 64)),
          const SizedBox(height: Insets.lg),
          Text(
            'Layla Pro Premium',
            textAlign: TextAlign.center,
            style: AppType.displayLg,
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Preview. Nothing is locked yet; this is how the offer will '
            'look at launch.',
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: AppColors.mist),
          ),
          const SizedBox(height: Insets.xxl),
          for (final ({String title, String detail}) b in kPremiumBenefits)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withValues(alpha: 0.14),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppColors.goldSoft,
                    ),
                  ),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(b.title, style: AppType.titleSm),
                        const SizedBox(height: 2),
                        Text(
                          b.detail,
                          style: AppType.bodySm.copyWith(color: AppColors.mist),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Insets.sm),
          const _CharityCard(),
          const SizedBox(height: Insets.xl),
          if (!premium.isPro) ...<Widget>[
            const SizedBox(height: Insets.sm),
            for (final PremiumPlan p in PremiumPlan.values)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.md),
                child: _PlanCard(
                  plan: p,
                  price: premium.priceFor(p),
                  selected: p == _plan,
                  best: p == PremiumPlan.yearly,
                  onTap: () => setState(() => _plan = p),
                ),
              ),
            const SizedBox(height: Insets.sm),
            PrimaryButton(
              label: _plan == PremiumPlan.lifetime
                  ? 'Buy once'
                  : 'Start ${_plan.label.toLowerCase()}',
              busy: premium.busy,
              onPressed: premium.busy
                  ? null
                  : () => ref.read(premiumProvider.notifier).buy(_plan),
            ),
            const SizedBox(height: Insets.sm),
            TextButton(
              onPressed: premium.busy
                  ? null
                  : () => ref.read(premiumProvider.notifier).restore(),
              child: const Text('Restore purchases'),
            ),
            if (premium.error != null) ...<Widget>[
              const SizedBox(height: Insets.sm),
              Text(
                premium.error!,
                textAlign: TextAlign.center,
                style: AppType.bodySm.copyWith(color: AppColors.rose),
              ),
            ],
            const SizedBox(height: Insets.lg),
            Text(
              'Subscriptions renew until cancelled in your '
              '${Have.enforcedAppLock ? 'Apple ID' : 'Google Play'} settings. '
              'Prayer times, ${Have.enforcedAppLock ? 'the shield' : 'prayer '
                        'focus'}, streaks and Tahajjud are free for everyone, '
              'always.',
              textAlign: TextAlign.center,
              style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
            ),
          ],
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.price,
    required this.selected,
    required this.best,
    required this.onTap,
  });

  final PremiumPlan plan;
  final String price;
  final bool selected;
  final bool best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.navyLine,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: selected
            ? <BoxShadow>[
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.16),
                  blurRadius: 20,
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.lg),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.md,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(plan.label, style: AppType.titleMd),
                          if (best) ...<Widget>[
                            const SizedBox(width: Insets.sm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'BEST VALUE',
                                style: AppType.label.copyWith(
                                  color: AppColors.midnight,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plan.blurb,
                        style: AppType.bodySm.copyWith(color: AppColors.mist),
                      ),
                    ],
                  ),
                ),
                Text(
                  price,
                  style: AppType.titleMd.copyWith(color: AppColors.goldSoft),
                ),
                const SizedBox(width: Insets.sm),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.gold : AppColors.mistFaint,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Where seven percent of every subscription goes, and how far it has got.
///
/// The bar is live from Firestore, so the number a subscriber sees is the
/// same number everyone sees, and it moves when the fund does. Trust is the
/// point of showing it at all, so nothing here is estimated on the phone.
class _CharityCard extends ConsumerWidget {
  const _CharityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CharityFund fund =
        ref.watch(charityFundProvider).value ?? const CharityFund();
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.emerald.withValues(alpha: 0.14),
                  border: Border.all(
                    color: AppColors.emerald.withValues(alpha: 0.5),
                  ),
                ),
                child: const Icon(
                  Icons.volunteer_activism_rounded,
                  size: 16,
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  'Seven percent goes to charity',
                  style: AppType.titleMd,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            'Seven percent of every subscription is set aside for those in need. '
            'We will show you where it goes, with pictures and receipts, not '
            'just a promise. Once there is enough, the plan is a masjid, and '
            'a page to follow its progress is coming to the app.',
            style: AppType.bodySm.copyWith(color: AppColors.mist, height: 1.5),
          ),
          const SizedBox(height: Insets.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                fund.money(fund.raised),
                style: AppType.titleLg.copyWith(color: AppColors.emerald),
              ),
              const SizedBox(width: Insets.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'of ${fund.money(fund.target)} set aside',
                  style: AppType.bodySm.copyWith(color: AppColors.mist),
                ),
              ),
              const Spacer(),
              Text(
                '${(fund.fraction * 100).round()}%',
                style: AppType.titleSm.copyWith(color: AppColors.mistFaint),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: fund.fraction),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double t, _) =>
                  LinearProgressIndicator(
                    value: t,
                    minHeight: 8,
                    backgroundColor: AppColors.navyLine,
                    color: AppColors.emerald,
                  ),
            ),
          ),
          if (fund.note != null && fund.note!.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.sm),
            Text(
              fund.note!,
              style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
            ),
          ],
          const SizedBox(height: Insets.sm),
          Text(
            'Live. Updates the moment the fund does.',
            style: AppType.bodySm.copyWith(
              color: AppColors.mistFaint,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
