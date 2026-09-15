import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../application/friends_controller.dart';
import '../../domain/jumuah.dart';

/// The masjid [uid] has named for this Friday, or null when they have not,
/// when it is not Friday, or while it is still loading.
///
/// One reading for the friend card and the you-card, so the two can never
/// disagree about when the line is shown.
String? masjidThisFriday(WidgetRef ref, String uid) {
  if (!ref.watch(isFridayProvider)) return null;
  final Jumuah? plan = ref.watch(jumuahProvider(uid)).valueOrNull;
  if (plan == null || !plan.isFor(DateTime.now())) return null;
  return plan.masjid;
}

/// One small line under a card's numbers: an icon and a sentence.
///
/// The prayers-together line, the Jumu'ah line and the Ramadan line are all
/// this shape, so they read as one column of quiet facts rather than three
/// different treatments.
class FriendLine extends StatelessWidget {
  const FriendLine({
    super.key,
    required this.icon,
    required this.text,
    this.color = AppColors.mist,
    this.trailing,
  });

  final IconData icon;
  final String text;
  final Color color;

  /// Something small after the sentence — the taraweeh moon.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Insets.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.bodySm.copyWith(color: color),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// The small crescent beside a Ramadan line when Taraweeh is being prayed.
class TaraweehMoon extends StatelessWidget {
  const TaraweehMoon({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 2),
    child: Icon(Icons.nightlight_round, size: 13, color: AppColors.goldSoft),
  );
}
