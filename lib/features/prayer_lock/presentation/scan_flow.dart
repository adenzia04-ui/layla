import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/permission_service.dart';
import '../../../core/config/platform_features.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../application/prayer_lock_controller.dart';
import '../domain/prayer_session.dart';
import 'mat_scanner_screen.dart';

/// "I have prayed", the Premium way: the camera slides up over whatever
/// screen the button is on, scans the mat, and slides back down to the same
/// screen. Nothing in between.
///
/// There used to be a page of its own here, black while it waited for the
/// camera, and it was the page people got stuck on. Now the flow is a call:
/// step one is recorded, the scanner is pushed on the root navigator, and
/// the result is handled right here, with the caller's screen still under it.
///
/// Returns true when the prayer was confirmed.
Future<bool> confirmWithScan(
  BuildContext context,
  WidgetRef ref,
  PrayerSession session,
) async {
  final PrayerLockController controller = ref.read(
    prayerLockControllerProvider.notifier,
  );

  // Step 1, unless an earlier attempt already recorded it.
  if (!session.awaitingProof) {
    final bool ok = await controller.beginConfirmation(session);
    if (!ok) {
      if (context.mounted) {
        context.showMessage(
          Have.enforcedAppLock
              ? 'That could not be saved. Your apps stay paused until it is.'
              : 'That could not be saved. Prayer focus stays on until it is.',
        );
      }
      return false;
    }
  }
  if (!context.mounted) return false;

  // The camera, asked for in place.
  final PermissionOutcome outcome = await ref
      .read(permissionServiceProvider)
      .requestCamera();
  if (!context.mounted) return false;
  if (outcome == PermissionOutcome.permanentlyDenied) {
    await _cameraBlocked(context, ref);
    return false;
  }
  if (!outcome.isGranted) {
    context.showError(
      'Layla Pro needs the camera to scan your prayer mat. '
      '${session.prayer.label} is not confirmed yet.',
    );
    return false;
  }

  final XFile? mat = await scanForPrayerMat(
    context,
    prayerLabel: session.prayer.label,
  );
  if (!context.mounted) return false;
  if (mat == null) {
    // Backed out. Not an error, and not a confirmation either.
    context.showMessage(
      '${session.prayer.label} is still unconfirmed. Scan your mat whenever '
      'you are ready.',
    );
    return false;
  }

  final bool ok = await controller.submitProof(session: session, photo: mat);
  if (!context.mounted) return ok;
  if (ok) {
    context.showSuccess(
      '${session.prayer.label} confirmed. May it be accepted.',
    );
  } else {
    context.showMessage(
      Have.enforcedAppLock
          ? 'The photo could not be saved. Your apps stay paused until it is.'
          : 'The photo could not be saved. Prayer focus stays on until it is.',
    );
  }
  return ok;
}

Future<void> _cameraBlocked(BuildContext context, WidgetRef ref) async {
  final bool? open = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      backgroundColor: AppColors.navy,
      title: Text('Camera access is blocked', style: AppType.titleLg),
      content: Text(
        'The prayer-mat scan needs the camera, so this prayer cannot be '
        'confirmed until you enable it in Settings.',
        style: AppType.bodySm.copyWith(color: AppColors.mist),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Open Settings'),
        ),
      ],
    ),
  );
  if (open ?? false) {
    await ref.read(permissionServiceProvider).openSettings();
  }
}
