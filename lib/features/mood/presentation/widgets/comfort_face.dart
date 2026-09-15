import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/mood_comfort.dart';

/// One passage as a card face: its source, the Arabic if it is Qur'an, the
/// meaning, and the citation that lets the reader find it themselves.
class ComfortFace extends StatelessWidget {
  const ComfortFace({
    super.key,
    required this.comfort,
    required this.tone,
    this.minHeight = 340,
    this.trailing,
  });

  final Comfort comfort;
  final Color tone;
  final double minHeight;

  /// Sits in the top-right corner — a bookmark, a play button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bool quran = comfort.source == ComfortSource.quran;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: tone.withValues(alpha: 0.55)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tone.withValues(alpha: 0.22),
            blurRadius: 40,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                quran ? Icons.menu_book_rounded : Icons.format_quote_rounded,
                size: 16,
                color: tone,
              ),
              const SizedBox(width: Insets.sm),
              Text(
                quran ? 'QUR\'AN' : 'HADITH',
                style: AppType.label.copyWith(color: tone),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          if (comfort.arabic != null) ...<Widget>[
            const SizedBox(height: Insets.lg),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                comfort.arabic!,
                textAlign: TextAlign.right,
                style: AppType.quran(26).copyWith(color: AppColors.cream),
              ),
            ),
          ],
          const SizedBox(height: Insets.lg),
          Text(
            comfort.english,
            style: AppType.body.copyWith(
              color: AppColors.cream,
              fontSize: 16,
              height: 1.65,
            ),
          ),
          const SizedBox(height: Insets.lg),
          Text(
            comfort.grade == null
                ? comfort.reference
                : '${comfort.reference} · ${comfort.grade}',
            style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
          ),
        ],
      ),
    );
  }
}
