import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/layla_mark.dart';
import '../../application/friends_controller.dart';
import '../../application/invite.dart';
import '../../domain/friend.dart';
import '../../../../core/widgets/platform_icons.dart';

/// "Your code": the six characters someone else types to find you.
///
/// Drawn as a small seal rather than a plain row — the mark, a hairline of
/// gold, the letters spaced out like a stamp — because this is the one thing
/// on the screen a person will hold up to somebody else, and it should look
/// like it was worth holding up.
class FriendCodeCard extends ConsumerWidget {
  const FriendCodeCard({super.key});

  /// What lands in the other person's messages when the code is shared: a
  /// link that opens the app on the add field with the code already in it,
  /// and shows the code to anyone without the app.
  static String shareText(String code) => inviteShareText(code);

  Future<void> _copy(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: FriendCode.display(code)));
    if (context.mounted) context.showSuccess('Code copied');
  }

  Future<void> _share(BuildContext context, String code) async {
    // iPad anchors its share popover to this rectangle; without one the
    // sheet has nowhere to point and the call fails.
    final RenderBox box = context.findRenderObject()! as RenderBox;
    await SharePlus.instance.share(
      ShareParams(
        text: shareText(code),
        sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<String?> code = ref.watch(myFriendCodeProvider);
    final String? value = code.valueOrNull;

    return NightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Seal(code: value, failed: code.hasError),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Expanded(
                child: _SealAction(
                  icon: Icons.copy_rounded,
                  label: 'Copy',
                  onPressed: value == null ? null : () => _copy(context, value),
                ),
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: _SealAction(
                  icon: kShareIcon,
                  label: 'Share',
                  onPressed: value == null
                      ? null
                      : () => _share(context, value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The hairline-framed plate with the mark and the code.
class _Seal extends ConsumerWidget {
  const _Seal({required this.code, required this.failed});

  final String? code;
  final bool failed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextStyle letters = AppType.displayMd.copyWith(
      color: code == null ? AppColors.mistFaint : AppColors.gold,
      letterSpacing: 6,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.lg,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.4),
          width: 0.8,
        ),
      ),
      child: Row(
        children: <Widget>[
          const LaylaMark(height: 24),
          const SizedBox(width: Insets.lg),
          Container(
            width: 1,
            height: 34,
            color: AppColors.gold.withValues(alpha: 0.3),
          ),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'FRIEND CODE',
                  style: AppType.label.copyWith(color: AppColors.goldDim),
                ),
                const SizedBox(height: Insets.xs),
                // Six middle dots hold the width while the code is on its
                // way, so the plate does not jump when it arrives.
                Text(
                  code == null ? '······' : FriendCode.display(code!),
                  style: letters,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (failed) ...<Widget>[
                  const SizedBox(height: Insets.xs),
                  GestureDetector(
                    onTap: () => ref.invalidate(myFriendCodeProvider),
                    child: Text(
                      'Your code could not be loaded. Tap to try again.',
                      style: AppType.bodySm.copyWith(color: AppColors.rose),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Copy and Share, side by side under the seal.
///
/// Shorter than the app's full-height ghost button: two 56pt pills under a
/// plate this small made the card read as mostly buttons.
class _SealAction extends StatelessWidget {
  const _SealAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: Insets.md),
        foregroundColor: AppColors.cream,
        textStyle: AppType.titleSm,
        side: BorderSide(color: AppColors.navyLine.withValues(alpha: 0.9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 17),
          const SizedBox(width: Insets.sm),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
