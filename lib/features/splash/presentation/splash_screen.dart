import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/routing/widget_links.dart';
import '../../widgets/data/widget_bridge.dart';
import '../../../core/services/prefs_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/mihrab_arch.dart';
import '../../../core/widgets/night_hero.dart';
import '../../../core/widgets/ornament_backdrop.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/widgets/layla_mark.dart';

/// Star field fades in, the gold arch draws itself, the wordmark rises, then
/// Noor decides where to send you.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// The build-up: sky, then arch, then mark, then wordmark and tagline.
  ///
  /// Slow on purpose. This screen is the app clearing its throat before Fajr,
  /// not a spinner to be got past — the arch is worth watching draw itself.
  static const Duration _build = Duration(milliseconds: 3400);

  /// How long the finished composition is held before moving on.
  static const Duration _hold = Duration(milliseconds: 900);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _build,
  );

  late final Animation<double> _sky = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.35, curve: Curves.easeOut),
  );
  late final Animation<double> _arch = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.15, 0.72, curve: Curves.easeInOutCubic),
  );
  late final Animation<double> _text = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.55, 0.9, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _tagline = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.72, 1, curve: Curves.easeOut),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    unawaited(_decideNextRoute());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Holds the splash until the build-up has finished and been let stand.
  ///
  /// The wait is derived from [_build] rather than written out again. It was a
  /// standalone 2100ms against a 2200ms animation, which navigated away while
  /// the tagline was still fading in — the last beat of the sequence never
  /// actually played. Two independent numbers meaning "the same moment" drift
  /// the instant either is touched, so now only one of them exists.
  Future<void> _decideNextRoute() async {
    await Future<void>.delayed(_build + _hold);
    if (!mounted) return;

    final bool onboarded = ref.read(prefsProvider).onboardingComplete;
    if (!onboarded) {
      context.go(Routes.onboarding);
      return;
    }

    final bool signedIn = ref.read(authRepositoryProvider).currentUser != null;
    if (!signedIn) {
      context.go(Routes.welcome);
      return;
    }

    // A home-screen widget started the app and asked for somewhere in
    // particular. It could not be honoured until now, because until now it
    // was not known whether this person had onboarded or was signed in.
    //
    // Two places to look. The router catches the link when the framework
    // hands it over, which it does reliably once the app is already running;
    // on a cold start it does not hand it over at all, and only the launch
    // intent still has it.
    String? fromWidget = ref.read(pendingWidgetLinkProvider);
    if (fromWidget == null) {
      final String? link = await ref.read(widgetBridgeProvider).consumeLaunchLink();
      if (link != null) fromWidget = widgetLinkTarget(Uri.parse(link));
      if (!mounted) return;
    }
    if (fromWidget != null) {
      ref.read(pendingWidgetLinkProvider.notifier).state = null;
      context.go(fromWidget);
      return;
    }

    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Stack(
            // Expand, or the Stack shrink-wraps to its widest *non-positioned*
            // child — the Column — and that is only as wide as its longest
            // line of text. `Positioned.fill` then fills 238px of a 393px
            // screen, so the night sky stopped dead at 61% with the scaffold's
            // flat midnight showing beside it. That was the split-down-the-
            // middle splash, not an engine race as first thought.
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: <Widget>[
              NightHero(
                starOpacity: _sky.value,
                skylineOpacity: _sky.value * 0.85,
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: _sky.value * 0.9,
                  child: const OrnamentBackdrop(height: 240, opacity: 0.13),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // The mihrab draws itself, then the mark rises inside it.
                  // The arch was carrying the whole screen on its own before,
                  // with a generic khatim in the middle — this is the app's
                  // own calligraphy instead, and it is the thing worth looking
                  // at, so it is bigger than the frame around it.
                  SizedBox(
                    height: 232,
                    width: 190,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        MihrabOutline(progress: _arch.value, strokeWidth: 1.6),
                        Opacity(
                          opacity: _text.value,
                          child: Transform.translate(
                            offset: Offset(0, 14 * (1 - _text.value)),
                            // No glow behind it. A gold BoxShadow at 18% over
                            // this navy composites to (52,62,78) — a flat grey
                            // disc rather than a halo, because gold that faint
                            // just desaturates. The arch already frames it.
                            // Centring the image in the arch does not centre
                            // the mark in it, for two reasons that were both
                            // measured rather than eyeballed.
                            //
                            // The art is cropped to its alpha bounding box,
                            // and the calligraphy's weight does not sit at the
                            // middle of that box — it is 2.5% of the width to
                            // the right and 6.2% of the height below it. And
                            // the mihrab is a dome on a straight base, so the
                            // centre of its opening is 3.2% of its height
                            // below the centre of the box it is drawn in.
                            //
                            // Together those put the mark's centre of weight
                            // 2.4pt right and 2.0pt below the middle of the
                            // niche. The old `bottom: 14` padding pushed it a
                            // further 7pt up, which is what left it sitting
                            // high with an empty floor under it.
                            child: Transform.translate(
                              offset: const Offset(-2.4, -2.0),
                              child: const LaylaMark(height: 152),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  Opacity(
                    opacity: _text.value,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - _text.value)),
                      child: Text(
                        'Layla Pro',
                        style: AppType.displayXl.copyWith(
                          color: AppColors.cream,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Insets.md),
                  Opacity(
                    opacity: _tagline.value,
                    child: Text(
                      'Stay connected with your prayers',
                      style: AppType.body.copyWith(color: AppColors.mist),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 64,
                child: Opacity(
                  opacity: _tagline.value,
                  child: SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: Radii.chip,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        value: _controller.value,
                        backgroundColor: AppColors.navyLine.withValues(
                          alpha: 0.6,
                        ),
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
