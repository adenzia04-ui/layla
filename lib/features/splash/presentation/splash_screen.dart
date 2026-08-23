import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/services/prefs_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/mihrab_arch.dart';
import '../../../core/widgets/night_hero.dart';
import '../../../core/widgets/ornament_backdrop.dart';
import '../../auth/data/auth_repository.dart';

/// Star field fades in, the gold arch draws itself, the wordmark rises, then
/// Noor decides where to send you.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
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

  /// Waits for both the animation and Firebase's first auth emission, so the
  /// splash never flashes past or hangs on a slow cold start.
  Future<void> _decideNextRoute() async {
    await Future<void>.delayed(const Duration(milliseconds: 2100));
    if (!mounted) return;

    final bool onboarded = ref.read(prefsProvider).onboardingComplete;
    if (!onboarded) {
      context.go(Routes.onboarding);
      return;
    }

    final bool signedIn = ref.read(authRepositoryProvider).currentUser != null;
    context.go(signedIn ? Routes.home : Routes.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return Stack(
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
                  SizedBox(
                    height: 168,
                    width: 132,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        MihrabOutline(progress: _arch.value, strokeWidth: 1.6),
                        Opacity(
                          opacity: _text.value,
                          child: const KhatimMark(
                            size: 40,
                            color: AppColors.goldSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Insets.xl),
                  Opacity(
                    opacity: _text.value,
                    child: Transform.translate(
                      offset: Offset(0, 16 * (1 - _text.value)),
                      child: Text(
                        'Layla',
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
                        backgroundColor:
                            AppColors.navyLine.withValues(alpha: 0.6),
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
