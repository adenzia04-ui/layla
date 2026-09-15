import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/services/notification_sounds.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../prayer_times/application/prayer_times_controller.dart';

/// Choose what a reminder sounds like, and hear each one first.
class SoundPicker extends ConsumerStatefulWidget {
  const SoundPicker({super.key});

  @override
  ConsumerState<SoundPicker> createState() => _SoundPickerState();
}

class _SoundPickerState extends ConsumerState<SoundPicker> {
  final AudioPlayer _player = AudioPlayer();
  ReminderSound? _playing;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _preview(ReminderSound sound) async {
    unawaited(HapticFeedback.selectionClick());
    if (_playing == sound) {
      setState(() => _playing = null);
      await _player.stop();
      return;
    }
    setState(() => _playing = sound);
    try {
      await _player.stop();
      await _player.setAsset(sound.asset);
      await _player.play();
    } on Object {
      // Fall through: whatever happened, it is not playing.
    }
    if (mounted && _playing == sound) setState(() => _playing = null);
  }

  Future<void> _choose(ReminderSound sound) async {
    unawaited(HapticFeedback.selectionClick());
    await ref.read(reminderSoundProvider.notifier).set(sound);
    // Reminders already queued carry the old file; queue them again.
    ref.invalidate(prayerNotificationSyncProvider);
  }

  @override
  Widget build(BuildContext context) {
    final ReminderSound chosen = ref.watch(reminderSoundProvider);
    return NightCard(
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.xs,
      ),
      child: Column(
        children: <Widget>[
          for (final ReminderSound s in ReminderSound.values)
            InkWell(
              onTap: () => _choose(s),
              borderRadius: BorderRadius.circular(Radii.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.sm,
                  vertical: Insets.sm,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      s == chosen
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_off_rounded,
                      size: 20,
                      color: s == chosen ? AppColors.gold : AppColors.mistFaint,
                    ),
                    const SizedBox(width: Insets.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(s.label, style: AppType.titleSm),
                          Text(
                            s.hint,
                            style: AppType.bodySm.copyWith(
                              color: AppColors.mistFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _preview(s),
                      tooltip: _playing == s ? 'Stop' : 'Preview',
                      icon: Icon(
                        _playing == s
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_outline_rounded,
                        color: _playing == s ? AppColors.gold : AppColors.mist,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.sm,
              Insets.xs,
              Insets.sm,
              Insets.sm,
            ),
            child: Text(
              'Plays with the ring switch on. Reminders already set are '
              'queued again with the new sound.',
              style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
            ),
          ),
        ],
      ),
    );
  }
}
