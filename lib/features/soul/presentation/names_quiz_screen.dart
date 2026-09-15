import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../application/name_speaker.dart';
import '../application/names_store.dart';
import '../domain/names_of_allah.dart';
import 'widgets/known_ring.dart';

/// Learn the ninety-nine: the Arabic is shown, three meanings are offered,
/// and a name answered right first time is counted as known.
class NamesQuizScreen extends ConsumerStatefulWidget {
  const NamesQuizScreen({super.key});

  @override
  ConsumerState<NamesQuizScreen> createState() => _NamesQuizScreenState();
}

class _NamesQuizScreenState extends ConsumerState<NamesQuizScreen> {
  final Random _rnd = Random();
  late int _index;
  late List<DivineName> _options;
  int? _chosen;
  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _draw();
  }

  /// Names not yet known come first; once they are all known, any name.
  void _draw() {
    final Set<int> known = ref.read(knownNamesProvider);
    final List<int> pool = <int>[
      for (int i = 0; i < NamesOfAllah.all.length; i++)
        if (!known.contains(i)) i,
    ];
    _index = pool.isEmpty
        ? _rnd.nextInt(NamesOfAllah.all.length)
        : pool[_rnd.nextInt(pool.length)];
    final DivineName right = NamesOfAllah.all[_index];
    final Set<DivineName> wrong = <DivineName>{};
    while (wrong.length < 2) {
      final DivineName d =
          NamesOfAllah.all[_rnd.nextInt(NamesOfAllah.all.length)];
      if (d != right && d.meaning != right.meaning) wrong.add(d);
    }
    _options = <DivineName>[right, ...wrong]..shuffle(_rnd);
    _chosen = null;
  }

  void _pick(int option) {
    if (_chosen != null) return;
    final bool right = _options[option] == NamesOfAllah.all[_index];
    setState(() {
      _chosen = option;
      _streak = right ? _streak + 1 : 0;
    });
    if (right) {
      HapticFeedback.lightImpact();
      ref.read(knownNamesProvider.notifier).add(_index);
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final DivineName name = NamesOfAllah.all[_index];
    final int known = ref.watch(knownNamesProvider).length;

    return NightScaffold(
      scrollable: true,
      ornamentHeight: 200,
      title: 'Learn the 99',
      leading: CircleIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        tooltip: 'Back',
        onPressed: () => context.pop(),
      ),
      actions: <Widget>[KnownRing(known: known, size: 40)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: Insets.xl),
          Text(
            known == 99
                ? 'All ninety-nine. Keep them warm.'
                : '$known of 99 known · '
                      '${_streak > 1 ? '$_streak in a row' : 'pick the meaning'}',
            textAlign: TextAlign.center,
            style: AppType.bodySm.copyWith(color: AppColors.mist),
          ),
          const SizedBox(height: Insets.xl),
          NightCard(
            padding: const EdgeInsets.all(Insets.xl),
            borderColor: AppColors.gold.withValues(alpha: 0.35),
            child: Column(
              children: <Widget>[
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    name.arabic,
                    textAlign: TextAlign.center,
                    style: AppType.quran(52).copyWith(
                      color: AppColors.goldSoft,
                      shadows: <Shadow>[
                        Shadow(
                          color: AppColors.gold.withValues(alpha: 0.45),
                          blurRadius: 28,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Insets.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      _chosen == null ? '· · ·' : name.transliteration,
                      style: AppType.displaySm.copyWith(
                        color: _chosen == null
                            ? AppColors.mistFaint
                            : AppColors.cream,
                      ),
                    ),
                    const SizedBox(width: Insets.sm),
                    CircleIconButton(
                      icon: Icons.volume_up_rounded,
                      tooltip: 'Hear it',
                      onPressed: () =>
                          ref.read(nameSpeakerProvider).say(name.arabic),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          for (int i = 0; i < _options.length; i++) ...<Widget>[
            _Option(
              label: _options[i].meaning,
              state: _chosen == null
                  ? _OptionState.open
                  : _options[i] == name
                  ? _OptionState.right
                  : i == _chosen
                  ? _OptionState.wrong
                  : _OptionState.dim,
              onTap: () => _pick(i),
            ),
            const SizedBox(height: Insets.md),
          ],
          const SizedBox(height: Insets.sm),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: _chosen == null ? 0 : 1,
            child: PrimaryButton(
              label: 'Next name',
              onPressed: _chosen == null ? null : () => setState(_draw),
            ),
          ),
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}

enum _OptionState { open, right, wrong, dim }

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color edge = switch (state) {
      _OptionState.right => AppColors.emerald,
      _OptionState.wrong => AppColors.rose,
      _OptionState.dim => AppColors.navyLine.withValues(alpha: 0.5),
      _OptionState.open => AppColors.navyLine,
    };
    final Color ink = switch (state) {
      _OptionState.right => AppColors.emerald,
      _OptionState.wrong => AppColors.rose,
      _OptionState.dim => AppColors.mistFaint,
      _OptionState.open => AppColors.cream,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
          color: edge,
          width: state == _OptionState.open ? 1 : 1.5,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.lg,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: AppType.titleSm.copyWith(color: ink),
                  ),
                ),
                if (state == _OptionState.right)
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppColors.emerald,
                  ),
                if (state == _OptionState.wrong)
                  const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.rose,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
