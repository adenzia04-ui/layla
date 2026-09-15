import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';

/// Guest mode is genuinely useful — but it is not free of trade-offs, and the
/// user deserves to see them before choosing, not after losing a 40-day streak.
Future<bool?> showGuestNoticeSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navy,
    builder: (BuildContext context) => const _GuestNoticeSheet(),
  );
}

class _GuestNoticeSheet extends StatelessWidget {
  const _GuestNoticeSheet();

  static const List<({IconData icon, String title, String body})> _works =
      <({IconData icon, String title, String body})>[
        (
          icon: Icons.check_circle_outline_rounded,
          title: 'Works as a guest',
          body: 'Prayer times, Qibla, Tasbih, Tahajjud times, and your streak.',
        ),
      ];

  static const List<({IconData icon, String title, String body})>
  _limits = <({IconData icon, String title, String body})>[
    (
      icon: Icons.cloud_off_rounded,
      title: 'Tied to this phone',
      body:
          'Your streak lives in a temporary account. Delete the app, switch '
          'phones, or clear its data and it is gone for good.',
    ),
    (
      icon: Icons.public_off_rounded,
      title: 'No Tahajjud map or Stories',
      body:
          'Appearing on the live map and sharing a story both need a real '
          'account, so the community stays accountable.',
    ),
    (
      icon: Icons.lock_reset_rounded,
      title: 'No recovery',
      body: 'There is no email or password, so nothing can be restored.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Insets.xl,
          Insets.sm,
          Insets.xl,
          Insets.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Continue without an account?', style: AppType.displaySm),
            const SizedBox(height: Insets.sm),
            Text(
              'You can start right away — here is exactly what you get and '
              'what you give up.',
              style: AppType.bodySm.copyWith(color: AppColors.mist),
            ),
            const SizedBox(height: Insets.xl),
            for (final ({IconData icon, String title, String body}) item
                in <({IconData icon, String title, String body})>[
                  ..._works,
                  ..._limits,
                ])
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      item.icon,
                      size: 20,
                      color: _works.contains(item)
                          ? AppColors.emerald
                          : AppColors.gold,
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(item.title, style: AppType.titleSm),
                          const SizedBox(height: 2),
                          Text(
                            item.body,
                            style: AppType.bodySm.copyWith(
                              color: AppColors.mistFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Insets.sm),
            Container(
              padding: const EdgeInsets.all(Insets.md),
              decoration: BoxDecoration(
                color: AppColors.navyElevated.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.upgrade_rounded,
                    size: 18,
                    color: AppColors.goldSoft,
                  ),
                  const SizedBox(width: Insets.sm),
                  Expanded(
                    child: Text(
                      'You can add an email and password later from Profile '
                      'and keep every day of your streak.',
                      style: AppType.bodySm.copyWith(color: AppColors.mist),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Insets.xl),
            PrimaryButton(
              label: 'Continue as guest',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: Insets.sm),
            GhostButton(
              label: 'Create an account instead',
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}
