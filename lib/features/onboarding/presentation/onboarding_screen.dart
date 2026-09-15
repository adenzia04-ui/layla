import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/services/prefs_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/mihrab_arch.dart';
import '../../../core/widgets/night_hero.dart';
import '../../../core/widgets/ornament_backdrop.dart';

class _Page {
  const _Page({
    required this.title,
    required this.body,
    required this.icon,
    this.features = const <({IconData icon, String label, String detail})>[],
  });

  final String title;
  final String body;
  final IconData icon;
  final List<({IconData icon, String label, String detail})> features;
}

const List<_Page> _pages = <_Page>[
  _Page(
    title: 'Welcome to Layla Pro',
    body: 'Stay connected with your prayers and strengthen your daily worship.',
    icon: Icons.auto_awesome_rounded,
  ),
  _Page(
    title: 'Never miss a prayer',
    body: 'Accurate times for where you are, and the direction to face.',
    icon: Icons.schedule_rounded,
    features: <({IconData icon, String label, String detail})>[
      (
        icon: Icons.access_time_rounded,
        label: 'Prayer Times',
        detail: 'All five prayers plus Tahajjud, with a live countdown',
      ),
      (
        icon: Icons.explore_rounded,
        label: 'Qibla',
        detail: 'A compass that points to the Kaaba wherever you stand',
      ),
    ],
  ),
  _Page(
    title: 'Worship, remembered',
    body:
        'Keep the dhikr flowing and rise for the quietest hours of the night.',
    icon: Icons.nights_stay_rounded,
    features: <({IconData icon, String label, String detail})>[
      (
        icon: Icons.radio_button_checked_rounded,
        label: 'Tasbih',
        detail: 'A digital counter with targets and progress',
      ),
      (
        icon: Icons.bedtime_rounded,
        label: 'Tahajjud',
        detail: 'See when the last third of the night begins',
      ),
    ],
  ),
  _Page(
    title: 'Build a streak that lasts',
    body:
        'Confirm each prayer in two steps and watch the days add up. Only '
        'confirmed prayers count.',
    icon: Icons.local_fire_department_rounded,
    features: <({IconData icon, String label, String detail})>[
      (
        icon: Icons.local_fire_department_rounded,
        label: 'Prayer Streaks',
        detail: 'Current streak, longest streak and a full history',
      ),
    ],
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await ref.read(prefsProvider).setOnboardingComplete(true);
    if (mounted) context.go(Routes.welcome);
  }

  void _next() {
    if (_isLast) {
      _finish();
      return;
    }
    _controller.nextPage(duration: Motion.normal, curve: Motion.enter);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: Stack(
        children: <Widget>[
          const NightHero(starOpacity: 0.9, skylineOpacity: 0.75),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: OrnamentBackdrop(height: 260, opacity: 0.12),
          ),
          SafeArea(
            child: Column(
              children: <Widget>[
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: Insets.md),
                    child: TextButton(
                      onPressed: _finish,
                      child: Text(
                        _isLast ? '' : 'Skip',
                        style: AppType.titleSm.copyWith(color: AppColors.mist),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (int i) => setState(() => _index = i),
                    itemBuilder: (BuildContext context, int i) =>
                        _OnboardingPage(page: _pages[i]),
                  ),
                ),
                _Dots(count: _pages.length, index: _index),
                const SizedBox(height: Insets.xl),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Insets.xxl,
                    0,
                    Insets.xxl,
                    Insets.lg,
                  ),
                  child: Column(
                    children: <Widget>[
                      PrimaryButton(
                        label: _isLast ? 'Get started' : 'Continue',
                        onPressed: _next,
                      ),
                      const SizedBox(height: Insets.sm),
                      SizedBox(
                        height: 48,
                        child: _isLast
                            ? TextButton(
                                onPressed: _finish,
                                child: const Text('I already have an account'),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Insets.xxl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 128,
            width: 100,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                const MihrabOutline(strokeWidth: 1.2),
                Icon(page.icon, color: AppColors.goldSoft, size: 30),
              ],
            ),
          ),
          const SizedBox(height: Insets.xxl),
          Text(page.title, style: AppType.displayLg),
          const SizedBox(height: Insets.md),
          Text(
            page.body,
            style: AppType.body.copyWith(color: AppColors.mist, height: 1.6),
          ),
          if (page.features.isNotEmpty) ...<Widget>[
            const SizedBox(height: Insets.xxl),
            for (final ({IconData icon, String label, String detail}) f
                in page.features)
              Padding(
                padding: const EdgeInsets.only(bottom: Insets.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: AppColors.navyElevated.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(Radii.sm),
                        border: Border.all(color: AppColors.navyLine),
                      ),
                      child: Icon(f.icon, size: 19, color: AppColors.gold),
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(f.label, style: AppType.titleSm),
                          const SizedBox(height: 2),
                          Text(
                            f.detail,
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
          ],
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: Motion.fast,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 6,
            width: i == index ? 22 : 6,
            decoration: BoxDecoration(
              color: i == index ? AppColors.gold : AppColors.navyLine,
              borderRadius: Radii.chip,
            ),
          ),
      ],
    );
  }
}
