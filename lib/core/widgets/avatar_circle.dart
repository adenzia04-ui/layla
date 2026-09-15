import 'package:flutter/material.dart';

import '../../features/profile/domain/avatar.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Someone's face, or their initials when there is no face to draw.
///
/// The one avatar in the app: your own on the profile and in the home header,
/// and a friend's on their card and in their sheet. Having a single widget is
/// what keeps a friend's circle the same shape as your own, and it means the
/// fallback is written once — which matters, because the fallback is what most
/// people will see for a long time after this ships.
///
/// It never throws. The picture is a base64 string copied from another
/// person's Firestore document, so it may be truncated, may be nonsense, and
/// may not be a JPEG at all; every one of those ends at the initials rather
/// than at a red error box on a friend's list.
class AvatarCircle extends StatelessWidget {
  const AvatarCircle({
    super.key,
    required this.initials,
    this.photo,
    this.size = 44,
    this.ring = true,
    this.gilded = false,
    this.onTap,
    this.semanticLabel,
  });

  /// One or two letters, drawn when there is no usable [photo].
  final String initials;

  /// A base64 JPEG, as stored — see [Avatar].
  final String? photo;

  final double size;

  /// The gold hairline around the circle.
  final bool ring;

  /// Fills the no-picture circle with the app's gold sheen and sets the
  /// letters in midnight, the way the profile has always drawn its owner.
  ///
  /// Only your own avatar on the profile screen asks for this. A friend's
  /// initials stay cream on navy, so the two never read as the same person,
  /// and the moment a picture is set the fill is irrelevant either way —
  /// which is why it lives here as a flag rather than as a second widget.
  final bool gilded;

  final VoidCallback? onTap;

  /// What a screen reader calls this circle when it can be tapped.
  ///
  /// Defaults to "Profile picture", which is right on the profile, where the
  /// tap opens the picture sheet. The home header is the same widget doing a
  /// different job — it navigates — and its no-photo sibling is a button
  /// labelled "Profile", so it passes that instead and the control keeps one
  /// name whether or not a picture has been set.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ImageProvider? image = Avatar.provider(photo);

    // The gold disc is the profile's own signature and it belongs to the
    // initials alone: a picture covers it completely, so painting it under
    // one would only show as a rim of gold where the photo does not reach.
    final bool gold = gilded && image == null;

    final Widget circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      // The picture is clipped by the container's own circle rather than by a
      // ClipOval inside it. A border on a Container pads its child, which
      // would leave a hairline of empty navy between the ring and the photo;
      // the ring goes on as a foreground decoration instead, painted over the
      // picture's edge the way a real rim would be.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: gold ? null : AppColors.navyElevated,
        gradient: gold ? AppColors.goldSheen : null,
      ),
      foregroundDecoration: ring && !gold
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1.5),
            )
          : null,
      child: image == null
          ? _initials(gold: gold)
          : Image(
              image: image,
              width: size,
              height: size,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              // A friend's card rebuilds every time they confirm a prayer. If
              // the provider is ever re-resolved the default is to clear the
              // frame first, which shows as the circle flashing empty navy;
              // holding the last frame is what makes that invisible.
              gaplessPlayback: true,
              // Valid base64 that is not a valid image gets past the decode in
              // Avatar.provider and fails later, inside the codec. That
              // failure is reported through the image stream, not thrown, so
              // the initials have to be the answer here as well.
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stack) =>
                      _initials(gold: gilded),
            ),
    );

    if (onTap == null) return circle;
    return Semantics(
      button: true,
      label: semanticLabel ?? 'Profile picture',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: circle,
        ),
      ),
    );
  }

  /// Cream letters on the elevated navy, sized to the circle.
  ///
  /// The letters do not follow the system text size. The circle is a fixed
  /// graphic that cannot grow with them, so at the top of the app's 1.3 clamp
  /// a wide pair like "WM" measures 41pt inside a 44pt circle and its stems
  /// run under the gold rim — which reads as a rendering fault rather than as
  /// large type. The padding reserves the rim and the [FittedBox] shrinks the
  /// rare wide pair instead of letting it cross.
  Widget _initials({bool gold = false}) => Padding(
    padding: EdgeInsets.all(size * 0.16),
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        initials,
        textScaler: TextScaler.noScaling,
        style: AppType.titleSm.copyWith(
          color: gold ? AppColors.midnight : AppColors.cream,
          fontWeight: gold ? FontWeight.w700 : null,
          fontSize: size * 0.34,
          letterSpacing: 0.6,
          height: 1,
        ),
      ),
    ),
  );
}
