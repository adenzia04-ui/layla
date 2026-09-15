import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/layla_mark.dart';
import '../../premium/application/premium_store.dart';
import '../../widgets/application/widget_theme_store.dart';
import '../../widgets/domain/widget_theme.dart';

/// Pick the colours the home-screen and Lock Screen widgets draw in.
///
/// The top of the screen is the home screen itself: Layla Pro's own prayer
/// arc widget and two small ones, drawn live in whichever set is chosen, so
/// the choice is made by seeing the widgets change rather than by reading a
/// colour's name. Under it, the sets as a row of stones: tap one and the
/// widgets above redraw in it.
class WidgetThemeScreen extends ConsumerStatefulWidget {
  const WidgetThemeScreen({super.key});

  @override
  ConsumerState<WidgetThemeScreen> createState() => _WidgetThemeScreenState();
}

class _WidgetThemeScreenState extends ConsumerState<WidgetThemeScreen> {
  /// The set being looked at. Locked ones can be previewed; only a free or
  /// unlocked set is saved.
  WidgetTheme? _looking;

  @override
  Widget build(BuildContext context) {
    final WidgetTheme saved = ref.watch(widgetThemeProvider);
    final bool unlocked = ref.watch(styleUnlockedProvider);
    final bool locks = ref.watch(styleLocksShownProvider);
    final WidgetTheme shown = _looking ?? saved;
    final bool previewingLocked = shown.isPremium && !unlocked;

    return NightScaffold(
      scrollable: true,
      ornamentHeight: 160,
      title: 'Widget colours',
      leading: CircleIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        tooltip: 'Back',
        onPressed: () => context.pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: Insets.lg),
          Text(
            'Every widget on your Home Screen and Lock Screen follows one '
            'set. Tap a stone to see it.',
            style: AppType.body.copyWith(color: AppColors.mist),
          ),
          const SizedBox(height: Insets.xl),
          _HomeScreenPreview(theme: shown),
          const SizedBox(height: Insets.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  shown.name,
                  style: AppType.titleLg.copyWith(color: AppColors.cream),
                ),
              ),
              if (shown == saved)
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.emerald,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'In use',
                      style: AppType.bodySm.copyWith(color: AppColors.emerald),
                    ),
                  ],
                )
              else if (shown.isPremium && locks)
                Row(
                  children: <Widget>[
                    const Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Premium',
                      style: AppType.bodySm.copyWith(color: AppColors.gold),
                    ),
                  ],
                ),
            ],
          ),
          Text(
            shown.tagline,
            style: AppType.bodySm.copyWith(color: AppColors.mist),
          ),
          const SizedBox(height: Insets.xl),
          Wrap(
            spacing: 10,
            runSpacing: Insets.lg,
            children: <Widget>[
              for (final WidgetTheme t in WidgetTheme.values)
                _Stone(
                  theme: t,
                  selected: t == shown,
                  inUse: t == saved,
                  locked: t.isPremium && locks,
                  onTap: () => _pick(t, unlocked),
                ),
            ],
          ),
          const SizedBox(height: Insets.xl),
          if (previewingLocked) ...<Widget>[
            PrimaryButton(
              label: 'Unlock with Premium',
              onPressed: () => context.push(Routes.paywall),
            ),
            const SizedBox(height: Insets.md),
            Text(
              'Midnight and Emerald are free. The other seven come with '
              'Premium, along with the counters.',
              textAlign: TextAlign.center,
              style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
            ),
          ] else
            Text(
              'The widgets redraw on their own within a minute. The app '
              'itself stays in Midnight.',
              textAlign: TextAlign.center,
              style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
            ),
          const SizedBox(height: Insets.xl),
        ],
      ),
    );
  }

  void _pick(WidgetTheme t, bool unlocked) {
    HapticFeedback.selectionClick();
    setState(() => _looking = t);
    if (t.isPremium && !unlocked) return; // looked at, not saved
    ref.read(widgetThemeProvider.notifier).set(t);
  }
}

/// A stone: the set's own ground with its accent as a ring, a lock on the
/// paid ones, and a gold halo on the one being looked at.
class _Stone extends StatelessWidget {
  const _Stone({
    required this.theme,
    required this.selected,
    required this.inUse,
    required this.locked,
    required this.onTap,
  });

  final WidgetTheme theme;
  final bool selected;
  final bool inUse;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const double size = 52;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 62,
        child: Column(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: size + 10,
              height: size + 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.gold : Colors.transparent,
                  width: 2,
                ),
                boxShadow: selected
                    ? <BoxShadow>[
                        BoxShadow(
                          color: theme.accent.withValues(alpha: 0.45),
                          blurRadius: 22,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[theme.top, theme.bottom],
                        ),
                        border: Border.all(
                          color: theme.text.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.accent, width: 3),
                          ),
                          child: inUse
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 12,
                                  color: theme.accent,
                                )
                              : null,
                        ),
                      ),
                    ),
                    if (locked)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.midnight,
                            border: Border.all(color: AppColors.navyLine),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            size: 11,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              theme.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.bodySm.copyWith(
                fontSize: 11,
                color: selected ? AppColors.cream : AppColors.mist,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The prayer-times widget, Layla Pro's own, drawn in the chosen set on a
/// patch of Home Screen. Cross-fades when the set changes.
class _HomeScreenPreview extends StatelessWidget {
  const _HomeScreenPreview({required this.theme});

  final WidgetTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.xl),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF2B3D4A), Color(0xFF16232D)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 380),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: _TimesWidget(key: ValueKey<WidgetTheme>(theme), theme: theme),
      ),
    );
  }
}

/// The large prayer-times widget: today, the countdown to the next prayer,
/// the six times in a grid with the next one lit, and Tahajjud underneath.
class _TimesWidget extends StatelessWidget {
  const _TimesWidget({super.key, required this.theme});

  final WidgetTheme theme;

  @override
  Widget build(BuildContext context) {
    final Color muted = theme.text.withValues(alpha: 0.6);
    final Color cell = theme.text.withValues(
      alpha: theme.isLight ? 0.07 : 0.08,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[theme.top, theme.bottom],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'TODAY',
                    style: AppType.label.copyWith(
                      color: theme.accent,
                      fontSize: 8,
                      letterSpacing: 1.3,
                    ),
                  ),
                  Text(
                    "2 Rabi' II 1448 AH",
                    style: AppType.bodySm.copyWith(
                      color: theme.text,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    'Sunday, 13 September',
                    style: AppType.bodySm.copyWith(color: muted, fontSize: 9),
                  ),
                  Row(
                    children: <Widget>[
                      Icon(Icons.near_me_rounded, size: 8, color: theme.accent),
                      const SizedBox(width: 3),
                      Text(
                        'Seri Kembangan',
                        style: AppType.bodySm.copyWith(
                          color: theme.text,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Until Dhuhr',
                    style: AppType.bodySm.copyWith(color: muted, fontSize: 9),
                  ),
                  Text(
                    '3:32:54',
                    style: AppType.numeral.copyWith(
                      color: theme.text,
                      fontSize: 30,
                      height: 1.1,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.accent.withValues(alpha: 0.7),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.wb_sunny_rounded, size: 12, color: theme.accent),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Dhuhr',
                          style: AppType.bodySm.copyWith(
                            color: theme.text,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          '1:10 PM',
                          style: AppType.bodySm.copyWith(
                            color: theme.text,
                            fontSize: 9,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: theme.text.withValues(alpha: 0.14), height: 1),
          const SizedBox(height: 10),
          for (final List<(String, String, IconData, bool)> row
              in <List<(String, String, IconData, bool)>>[
                <(String, String, IconData, bool)>[
                  ('Fajr', '5:56 AM', Icons.auto_awesome_rounded, false),
                  ('Shurooq', '7:05 AM', Icons.wb_twilight_rounded, false),
                  ('Dhuhr', '1:10 PM', Icons.wb_sunny_rounded, true),
                ],
                <(String, String, IconData, bool)>[
                  ('Asr', '4:11 PM', Icons.wb_sunny_outlined, false),
                  ('Maghrib', '7:13 PM', Icons.wb_twilight_rounded, false),
                  ('Isha', '8:18 PM', Icons.nightlight_round, false),
                ],
              ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  for (final (String n, String t, IconData i, bool lit) in row)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: lit
                              ? theme.accent.withValues(alpha: 0.18)
                              : cell,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: lit
                                ? theme.accent.withValues(alpha: 0.8)
                                : Colors.transparent,
                          ),
                        ),
                        child: Column(
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  i,
                                  size: 9,
                                  color: lit ? theme.accent : muted,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  n,
                                  style: AppType.bodySm.copyWith(
                                    color: lit ? theme.text : muted,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              t,
                              style: AppType.bodySm.copyWith(
                                color: lit ? theme.text : muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Icon(Icons.bedtime_rounded, size: 10, color: theme.accent),
              const SizedBox(width: 5),
              Text(
                'Tahajjud from 2:22 AM',
                style: AppType.bodySm.copyWith(color: muted, fontSize: 9),
              ),
              const Spacer(),
              ColorFiltered(
                colorFilter: ColorFilter.mode(theme.accent, BlendMode.srcATop),
                child: const LaylaMark(height: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
