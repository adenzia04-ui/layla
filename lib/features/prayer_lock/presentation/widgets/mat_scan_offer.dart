import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// The mat scan, shown to somebody who does not have it.
///
/// It used to be shown to nobody. A free confirmation is one honest tap and
/// the streak moves the same way, which is right — but the paid alternative
/// was not drawn at all, so the screen where it would be used said nothing
/// about it existing. The Profile row offers Premium, the paywall lists the
/// mat scan as the first thing it buys, and the one place a person is
/// actually deciding how to confirm a prayer stayed silent. Read from the
/// phone rather than from the code, that is indistinguishable from a feature
/// that is broken — and it was reported as exactly that.
///
/// The colour stones in Widgets already do this properly: the paid ones are
/// drawn with a lock rather than hidden, so the offer can be seen and turned
/// down. This is the same, in the same words.
class MatScanOffer extends StatelessWidget {
  const MatScanOffer({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Insets.sm),
      child: InkWell(
        onTap: () => context.push(Routes.paywall),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.center_focus_strong_rounded,
                size: 18,
                color: AppColors.mistFaint,
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Text(
                  'Or scan your prayer mat, so the streak is proof rather '
                  'than a promise.',
                  style: AppType.bodySm.copyWith(
                    color: AppColors.mistFaint,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: Insets.sm),
              const Icon(Icons.lock_rounded, size: 13, color: AppColors.gold),
              const SizedBox(width: 4),
              Text(
                'Premium',
                style: AppType.bodySm.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
