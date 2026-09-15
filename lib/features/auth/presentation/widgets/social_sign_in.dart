import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../application/auth_controller.dart';
import '../../data/auth_repository.dart';
import 'google_mark.dart';
import 'name_prompt_sheet.dart';

/// Apple and Google, on every screen where an account can be reached.
///
/// Shared rather than copied because App Store Review Guideline 4.8 applies
/// per screen, not per app: anywhere Google is offered, Apple has to be
/// offered too and must not be the lesser option. Two copies of that rule
/// would drift apart the first time one screen was edited and the other was
/// not, and the way you find out is a rejected build.
class SocialSignIn extends ConsumerStatefulWidget {
  const SocialSignIn({super.key, required this.onLight, this.beside});

  /// True on the light auth sheet, false on the navy welcome screen.
  ///
  /// Apple's own guidance is that the button is black on light and white on
  /// dark, so this is not only about matching the surface behind it.
  final bool onLight;

  /// An optional button to sit beside Google — the welcome screen puts
  /// "Email" there. Null gives Google the full width.
  final Widget? beside;

  @override
  ConsumerState<SocialSignIn> createState() => _SocialSignInState();
}

class _SocialSignInState extends ConsumerState<SocialSignIn> {
  /// Which button is mid-flight, so only that one spins.
  String? _tag;

  Future<void> _run(String tag, Future<bool> Function() action) async {
    if (_tag != null) return;
    setState(() => _tag = tag);
    final bool ok = await action();
    if (!mounted) return;
    setState(() => _tag = null);
    if (!ok) return;

    // Ask before leaving for Home, not after. A person greeted as "friend"
    // has no way to know the app simply was not told their name, and no
    // reason to go hunting through Account settings for the field that fixes
    // it.
    if (ref.read(authRepositoryProvider).needsDisplayName) {
      await showNamePromptSheet(context, ref);
      if (!mounted) return;
    }
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    // The controller is the one place that knows an auth call is in flight, so
    // an email login already running disables these too.
    final bool busy = ref.watch(authControllerProvider).isLoading;
    final AuthController auth = ref.read(authControllerProvider.notifier);

    final Widget google = SocialButton(
      label: 'Google',
      mark: const GoogleMark(),
      onLight: widget.onLight,
      busy: _tag == 'google',
      onPressed: busy ? null : () => _run('google', auth.signInWithGoogle),
    );

    return Column(
      children: <Widget>[
        // Apple first, and full width. Guideline 4.8 again — it may not be
        // presented as the smaller of the two. On Android there is no such
        // button to show.
        if (Platform.isIOS) ...<Widget>[
          SocialButton(
            label: 'Continue with Apple',
            icon: Icons.apple_rounded,
            onLight: widget.onLight,
            filled: true,
            busy: _tag == 'apple',
            onPressed: busy ? null : () => _run('apple', auth.signInWithApple),
          ),
          const SizedBox(height: Insets.md),
        ],
        if (widget.beside == null)
          google
        else
          Row(
            children: <Widget>[
              Expanded(child: widget.beside!),
              const SizedBox(width: Insets.md),
              Expanded(child: google),
            ],
          ),
      ],
    );
  }
}

/// One pill-shaped sign-in button, on either surface.
class SocialButton extends StatelessWidget {
  const SocialButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.mark,
    this.onLight = false,
    this.filled = false,
    this.busy = false,
  }) : assert(icon != null || mark != null, 'a button needs a mark');

  final String label;

  /// A monochrome glyph, tinted to match the button.
  final IconData? icon;

  /// A mark that brings its own colours — Google's, which may not be tinted.
  final Widget? mark;
  final VoidCallback? onPressed;
  final bool onLight;

  /// The primary of the pair — Apple. Solid rather than outlined.
  final bool filled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final Color background = filled
        ? (onLight ? AppColors.ink : AppColors.cream)
        : (onLight ? AppColors.bone : AppColors.navyElevated);
    final Color foreground = filled
        ? (onLight ? AppColors.bone : AppColors.midnight)
        : (onLight ? AppColors.ink : AppColors.cream);
    final Color edge = filled
        ? background
        : (onLight ? AppColors.boneMuted : AppColors.navyLine);

    return SizedBox(
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: Radii.chip,
          border: Border.all(color: edge),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: Radii.chip,
            onTap: busy ? null : onPressed,
            child: Center(
              child: busy
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: foreground,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        mark ?? Icon(icon, size: 21, color: foreground),
                        const SizedBox(width: Insets.sm),
                        // Flexible for the same reason every other button in
                        // the app is: at 1.3x text these labels outgrow a
                        // half-width button.
                        Flexible(
                          child: Text(
                            label,
                            style: AppType.button.copyWith(color: foreground),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
