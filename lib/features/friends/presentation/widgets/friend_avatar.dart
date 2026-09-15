import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/avatar_circle.dart';

/// A friend's picture, or their initials — how they appear on the list and at
/// the top of their sheet.
///
/// Nothing but [AvatarCircle] with a name that reads properly at the call
/// site. It stays because a friend's avatar is fed from their published
/// progress rather than from a profile, and the two should not be confusable
/// where they are used.
class FriendAvatar extends StatelessWidget {
  const FriendAvatar({
    super.key,
    required this.initials,
    this.photo,
    this.size = 44,
  });

  final String initials;

  /// Their published picture, base64, or null until they have set one.
  final String? photo;

  final double size;

  @override
  Widget build(BuildContext context) =>
      AvatarCircle(initials: initials, photo: photo, size: size);
}

/// Five dots, one per prayer, filled left to right as the day is prayed.
///
/// The same five-dot idea as the year view on the streak screen, at a glance
/// size: filled emerald for what is done, an outline for what is still to
/// come.
class PrayerDots extends StatelessWidget {
  const PrayerDots({super.key, required this.completed, this.size = 8});

  final int completed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final int done = completed.clamp(0, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < 5; i++) ...<Widget>[
          if (i > 0) SizedBox(width: size / 2),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < done ? AppColors.emerald : null,
              border: i < done
                  ? null
                  : Border.all(color: AppColors.navyLine, width: 1.4),
            ),
          ),
        ],
      ],
    );
  }
}
