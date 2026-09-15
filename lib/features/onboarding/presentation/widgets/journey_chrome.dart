import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// How far through the journey, drawn as a filled rule.
///
/// Gold on navy line, not a coloured gradient. The progress bar is the only
/// thing on screen at every single step, so it has to sit quietly — anything
/// brighter competes with the question, which is the one thing being asked.
class JourneyProgress extends StatelessWidget {
  const JourneyProgress({required this.value, super.key});

  /// 0..1.
  final double value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, _) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: t.clamp(0.02, 1),
          minHeight: 5,
          backgroundColor: AppColors.navyLine,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
        ),
      ),
    );
  }
}

/// One choice in a list of them.
///
/// Selection is shown by the border and a gold dot rather than by filling the
/// tile. A filled tile at this size reads as a pressed button — people tapped
/// it twice, then wondered why nothing happened.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.detail,
    this.leading,
    super.key,
  });

  final String label;
  final String? detail;
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: Insets.lg,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.navyElevated : AppColors.navy,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.navyLine,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: Insets.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: AppType.titleMd),
                    if (detail != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        detail!,
                        style: AppType.bodySm.copyWith(
                          color: AppColors.mistFaint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Insets.sm),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 22,
                width: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.gold : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.gold : AppColors.navyLine,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: AppColors.midnight,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A line of prose with certain words lifted into gold.
///
/// The reflection steps are the only place the app raises its voice, and they
/// do it by colouring a number rather than by shouting in bold — a screen that
/// tells someone they will spend six years on their phone does not need help
/// landing.
class AccentedText extends StatelessWidget {
  const AccentedText(
    this.spans, {
    this.style,
    this.align = TextAlign.left,
    super.key,
  });

  /// Alternating plain and accented runs, starting plain.
  final List<String> spans;
  final TextStyle? style;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final TextStyle base = (style ?? AppType.displaySm).copyWith(
      color: AppColors.cream,
    );
    return RichText(
      textAlign: align,
      text: TextSpan(
        style: base,
        children: <InlineSpan>[
          for (int i = 0; i < spans.length; i++)
            TextSpan(
              text: spans[i],
              style: i.isOdd ? base.copyWith(color: AppColors.gold) : null,
            ),
        ],
      ),
    );
  }
}
