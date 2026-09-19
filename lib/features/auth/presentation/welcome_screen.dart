import 'package:flutter/material.dart';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/layla_mark.dart';
import '../application/auth_controller.dart';
import 'widgets/guest_notice_sheet.dart';
import 'widgets/social_sign_in.dart';

/// The first thing a new person sees, and the reason the streak is worth
/// keeping.
///
/// Layla Pro stores a prayer history, and until now the only way to carry it was
/// an email and a password. That is the one credential people forget, so a
/// streak built over months died with the phone it started on. Apple and
/// Google are credentials nobody has to remember — sign in on a new phone
/// with the same Apple ID and the history is already there.
///
/// The benefits list is deliberately about *this* app: what Layla Pro will keep
/// for you, in the words the rest of the app uses for those things.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  /// Which button is mid-flight, so only that one shows a spinner.
  String? _busy;

  Future<void> _run(String tag, Future<bool> Function() action) async {
    if (_busy != null) return;
    setState(() => _busy = tag);
    final bool ok = await action();
    if (!mounted) return;
    setState(() => _busy = null);
    if (ok) context.go(Routes.home);
  }

  /// The ✕. Skipping is allowed, but not silently: the sheet spells out what
  /// a guest account cannot do before one is created, because the thing it
  /// cannot do — be signed back into — is discovered far too late otherwise.
  Future<void> _skip() async {
    if (await showGuestNoticeSheet(context) != true) return;
    if (!mounted) return;
    await _run(
      'guest',
      ref.read(authControllerProvider.notifier).continueAsGuest,
    );
  }

  /// The ?. Answers the question this screen actually raises — why an app
  /// about prayer wants an account at all — rather than repeating the benefits
  /// list that is already on screen underneath it.
  Future<void> _explain() {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.navy,
      shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsets.all(Insets.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Why sign in?', style: AppType.displaySm),
            const SizedBox(height: Insets.md),
            Text(
              'Layla Pro keeps a record of the prayers you confirm. That record is '
              'the streak, and it has to live somewhere that survives a lost '
              'phone — otherwise months of it disappear with the handset.',
              style: AppType.bodySm.copyWith(
                color: AppColors.mist,
                height: 1.5,
              ),
            ),
            const SizedBox(height: Insets.md),
            Text(
              // The Apple button is correctly hidden on Android — so naming
              // it here offered a way in that is not on the screen, on the
              // first thing anyone reads about signing in.
              '${Platform.isIOS ? 'Signing in with Apple or Google' : 'Signing in with Google'} '
              'means there is no password to forget. Layla Pro receives your '
              'name and email and nothing else — not your contacts, not your '
              'photos, and never the prayer-mat photos, which stay on this '
              'phone and are not uploaded anywhere.',
              style: AppType.bodySm.copyWith(
                color: AppColors.mistFaint,
                height: 1.5,
              ),
            ),
            const SizedBox(height: Insets.xl),
            PrimaryButton(
              label: 'Got it',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A failure parked by the controller — a wrong account, no network, or on
    // a build without the capability, Apple refusing the request outright.
    ref.listen<AsyncValue<void>>(authControllerProvider, (
      AsyncValue<void>? was,
      AsyncValue<void> now,
    ) {
      if (now.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.navyElevated,
            content: Text(
              now.error.toString(),
              style: AppType.bodySm.copyWith(color: AppColors.cream),
            ),
          ),
        );
      }
    });

    return NightScaffold(
      scrollable: true,
      ornamentHeight: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: Insets.sm),
          Row(
            children: <Widget>[
              CircleIconButton(
                icon: Icons.help_outline_rounded,
                tooltip: 'Why sign in?',
                onPressed: _explain,
              ),
              const Expanded(child: Center(child: LaylaMark(height: 46))),
              CircleIconButton(
                icon: Icons.close_rounded,
                tooltip: 'Skip for now',
                onPressed: _busy != null ? null : _skip,
              ),
            ],
          ),
          const SizedBox(height: Insets.lg),
          Text(
            'Salaam',
            textAlign: TextAlign.center,
            style: AppType.titleSm.copyWith(color: AppColors.gold),
          ),
          const SizedBox(height: 4),
          Text(
            'Keep your prayers with you',
            textAlign: TextAlign.center,
            style: AppType.displayLg,
          ),
          const SizedBox(height: Insets.sm),
          Text(
            'Sign in once and Layla Pro remembers — on this phone, and on the '
            'next one.',
            textAlign: TextAlign.center,
            style: AppType.bodySm.copyWith(color: AppColors.mist),
          ),
          const SizedBox(height: Insets.xxl),

          const _Benefits(),
          const SizedBox(height: Insets.xxl),

          SocialSignIn(
            onLight: false,
            beside: SocialButton(
              label: 'Email',
              icon: Icons.mail_outline_rounded,
              onPressed: () => context.push(Routes.login),
            ),
          ),
          const SizedBox(height: Insets.lg),

          TextButton(
            onPressed: _busy != null
                ? null
                : () => _run(
                    'guest',
                    ref.read(authControllerProvider.notifier).continueAsGuest,
                  ),
            style: TextButton.styleFrom(foregroundColor: AppColors.mist),
            child: const Text('Continue without an account'),
          ),
          const SizedBox(height: Insets.xs),

          // Said plainly, because it is the one thing a guest cannot undo by
          // themselves later without help.
          Text(
            'A guest account lives on this phone only. Signing in later keeps '
            'the streak you have already built.',
            textAlign: TextAlign.center,
            style: AppType.bodySm.copyWith(
              fontSize: 11,
              color: AppColors.mistFaint,
            ),
          ),
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}

/// What an account actually buys — every line a thing Layla Pro already does.
class _Benefits extends StatelessWidget {
  const _Benefits();

  static const List<(IconData, String)> _items = <(IconData, String)>[
    (Icons.local_fire_department_rounded, 'Your prayer streak, kept safe'),
    (Icons.check_circle_outline_rounded, 'Every prayer you confirm'),
    (Icons.access_time_rounded, 'Prayer times and adhan for where you are'),
    (Icons.radio_button_checked_rounded, 'Tasbih counts and sunnah routines'),
    (Icons.menu_book_rounded, 'Starred duas and where you left off'),
    (Icons.nightlight_round, 'Your Tahajjud nights on the map'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(Insets.lg),
    decoration: BoxDecoration(
      color: AppColors.navyElevated,
      borderRadius: Radii.card,
      border: Border.all(color: AppColors.navyLine),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'WHAT AN ACCOUNT KEEPS',
          style: AppType.label.copyWith(color: AppColors.gold),
        ),
        const SizedBox(height: Insets.md),
        for (final (IconData icon, String text) in _items)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(icon, size: 17, color: AppColors.gold),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    text,
                    style: AppType.bodySm.copyWith(color: AppColors.cream),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
