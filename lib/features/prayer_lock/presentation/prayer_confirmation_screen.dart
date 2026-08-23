import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/routing/routes.dart';
import '../../../core/services/permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../prayer_times/domain/prayer.dart';
import '../application/prayer_lock_controller.dart';
import '../domain/prayer_session.dart';

/// The two-step confirmation.
///
/// Step 1 is already recorded by the time this screen opens. Step 2 — the
/// prayer-mat photo — is **required**: there is no path from here to
/// `completed` that does not go through a successful upload.
class PrayerConfirmationScreen extends ConsumerStatefulWidget {
  const PrayerConfirmationScreen({super.key, required this.prayerKey});

  final String prayerKey;

  @override
  ConsumerState<PrayerConfirmationScreen> createState() =>
      _PrayerConfirmationScreenState();
}

class _PrayerConfirmationScreenState
    extends ConsumerState<PrayerConfirmationScreen> {
  bool _stepOneRecorded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordStepOne());
  }

  /// Runs once when the screen opens: this *is* Step 1.
  Future<void> _recordStepOne() async {
    final PrayerSession? session = ref.read(activeSessionProvider);
    if (session == null || session.awaitingProof) {
      setState(() => _stepOneRecorded = true);
      return;
    }
    final bool ok = await ref
        .read(prayerLockControllerProvider.notifier)
        .beginConfirmation(session);
    if (mounted) setState(() => _stepOneRecorded = ok);
  }

  /// Camera only — deliberately.
  ///
  /// Picking from the gallery let the same saved photo confirm every prayer
  /// forever, which removes the only thing this step actually provides: the
  /// friction of getting up and pointing a camera at your mat. A live capture
  /// cannot be a screenshot or a reused image.
  Future<void> _submit() async {
    final PrayerSession? session = ref.read(activeSessionProvider);
    if (session == null) return;

    final PermissionOutcome outcome =
        await ref.read(permissionServiceProvider).requestCamera();
    if (!mounted) return;
    if (outcome == PermissionOutcome.permanentlyDenied) {
      await _showCameraBlockedDialog();
      return;
    }
    if (!outcome.isGranted) {
      context.showError(
        'Layla needs the camera to take the prayer-mat photo. '
        'This prayer is not confirmed yet.',
      );
      return;
    }

    final bool ok = await ref
        .read(prayerLockControllerProvider.notifier)
        .submitProof(session: session, source: ImageSource.camera);

    if (!mounted) return;
    if (ok) {
      context
        ..showSuccess('${session.prayer.label} confirmed. May it be accepted.')
        ..go(Routes.home);
    }
  }

  Future<void> _showCameraBlockedDialog() async {
    final bool? open = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: Text('Camera access is blocked', style: AppType.titleLg),
        content: Text(
          'The prayer-mat photo has to be taken with the camera, so this '
          'prayer cannot be confirmed until you enable it in Settings.',
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

  /// Leaving without a photo is allowed — but it must be an informed choice,
  /// and the prayer stays unconfirmed.
  Future<void> _confirmExit() async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.navy,
        title: Text('Leave without confirming?', style: AppType.titleLg),
        content: Text(
          'Without the prayer-mat photo this prayer stays unconfirmed, it will '
          'not count toward your streak, and the prayer focus screen stays '
          'open for the rest of the window.',
          style: AppType.bodySm.copyWith(color: AppColors.mist),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.rose),
            child: const Text('Leave unconfirmed'),
          ),
        ],
      ),
    );
    if ((leave ?? false) && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final PrayerId prayer =
        PrayerId.fromKey(widget.prayerKey) ?? PrayerId.fajr;
    final AsyncValue<void> action = ref.watch(prayerLockControllerProvider);
    final double? progress = ref.watch(proofUploadProgressProvider);

    ref.listen<AsyncValue<void>>(prayerLockControllerProvider,
        (AsyncValue<void>? previous, AsyncValue<void> next) {
      if (next.hasError && !next.isLoading) context.showError(next.error!);
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) _confirmExit();
      },
      child: NightScaffold(
        showOrnaments: true,
        ornamentHeight: 220,
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: Insets.sm),
            Row(
              children: <Widget>[
                CircleIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Cancel confirmation',
                  onPressed: _confirmExit,
                ),
                const Spacer(),
                Text(
                  'CONFIRM ${prayer.label.toUpperCase()}',
                  style: AppType.label.copyWith(color: AppColors.gold),
                ),
                const Spacer(),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: Insets.xl),
            _StepIndicator(stepOneDone: _stepOneRecorded),
            const SizedBox(height: Insets.xxl),
            Text('Step 2 of 2', style: AppType.label.copyWith(
              color: AppColors.gold,
            ),),
            const SizedBox(height: Insets.sm),
            Text(
              'Upload a photo of your prayer mat to complete your prayer '
              'confirmation.',
              style: AppType.displaySm.copyWith(height: 1.35),
            ),
            const SizedBox(height: Insets.md),
            Text(
              'The photo is required. Until it uploads, ${prayer.label} stays '
              'unconfirmed and will not count toward your streak.',
              style: AppType.body.copyWith(color: AppColors.mist),
            ),
            const SizedBox(height: Insets.xxl),
            if (progress != null)
              _UploadProgressCard(progress: progress)
            else ...<Widget>[
              PrimaryButton(
                label: 'Take a photo',
                icon: Icons.photo_camera_rounded,
                busy: action.isLoading,
                onPressed: _submit,
              ),
            ],
            const SizedBox(height: Insets.xxl),
            const _PrivacyNote(),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.stepOneDone});

  final bool stepOneDone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _StepPill(
          index: 1,
          label: 'I have prayed',
          done: stepOneDone,
          active: !stepOneDone,
        ),
        Container(
          width: 24,
          height: 1.5,
          color: stepOneDone ? AppColors.emerald : AppColors.navyLine,
        ),
        _StepPill(
          index: 2,
          label: 'Prayer mat photo',
          done: false,
          active: stepOneDone,
        ),
      ],
    );
  }
}

class _StepPill extends StatelessWidget {
  const _StepPill({
    required this.index,
    required this.label,
    required this.done,
    required this.active,
  });

  final int index;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color color = done
        ? AppColors.emerald
        : active
            ? AppColors.gold
            : AppColors.mistFaint;
    return Expanded(
      child: Column(
        children: <Widget>[
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(color: color, width: 1.4),
            ),
            child: done
                ? const Icon(Icons.check_rounded,
                    size: 18, color: AppColors.emerald,)
                : Center(
                    child: Text(
                      '$index',
                      style: AppType.titleSm.copyWith(color: color),
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppType.bodySm.copyWith(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}

class _UploadProgressCard extends StatelessWidget {
  const _UploadProgressCard({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return NightCard(
      padding: const EdgeInsets.all(Insets.xl),
      child: Column(
        children: <Widget>[
          Text('Saving your photo…', style: AppType.titleMd),
          const SizedBox(height: Insets.lg),
          ClipRRect(
            borderRadius: Radii.chip,
            child: LinearProgressIndicator(
              minHeight: 6,
              value: progress,
              backgroundColor: AppColors.navyLine,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: Insets.md),
          Text(
            '${(progress * 100).round()}% — do not close Layla until this '
            'finishes.',
            textAlign: TextAlign.center,
            style: AppType.bodySm.copyWith(color: AppColors.mist),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return NightCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.lock_outline_rounded,
              size: 19, color: AppColors.goldDim,),
          const SizedBox(width: Insets.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('This photo never leaves your phone',
                    style: AppType.titleSm,),
                const SizedBox(height: 4),
                Text(
                  'It is saved in Layla\'s private storage on this device — not '
                  'uploaded to any server. Nobody else can see it, it is never '
                  'posted to the map or Stories, and there is no way to share '
                  'it from inside Layla. Photos older than 90 days are deleted '
                  'automatically.',
                  style: AppType.bodySm
                      .copyWith(color: AppColors.mistFaint, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
