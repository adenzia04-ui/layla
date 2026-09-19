import 'package:flutter/material.dart';
import 'dart:io';

import '../../prayer_lock/domain/mat_check.dart';
import '../../prayer_lock/data/proof_repository.dart';
import '../../prayer_lock/data/mat_vision.dart';
import '../../prayer_lock/presentation/mat_scanner_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/platform_features.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/battery_exemption.dart';
import '../../../core/routing/routes.dart';
import 'widgets/sound_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/section_header.dart';
import '../../prayer_lock/application/prayer_lock_sync.dart';
import '../../prayer_lock/data/prayer_lock_platform.dart';
import '../../prayer_times/application/prayer_times_controller.dart';
import '../../prayer_times/data/prayer_settings_repository.dart';
import '../../prayer_times/domain/prayer.dart';
import '../../prayer_times/domain/prayer_settings.dart';
import '../../widgets/application/live_activity_toggle.dart';

/// Reminders, the prayer focus window, and the native lock.
///
/// This screen is where Noor is honest about what each operating system will
/// and will not allow — see `docs/PRAYER_LOCK_LIMITATIONS.md`.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrayerSettings settings = ref.watch(prayerSettingsProvider);
    final PrayerSettingsRepository repo = ref.watch(
      prayerSettingsRepositoryProvider,
    );
    final AsyncValue<LockPermissions> lock = ref.watch(lockPermissionsProvider);

    return NightScaffold(
      scrollable: true,
      ornamentHeight: 180,
      title: 'Reminders & focus',
      leading: CircleIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        onPressed: () => context.pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.xxxl),
          const SectionHeader(label: 'Prayer reminders'),
          NightCard(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.xs,
            ),
            child: Column(
              children: <Widget>[
                for (final PrayerId id in <PrayerId>[
                  ...PrayerId.obligatory,
                  PrayerId.tahajjud,
                ])
                  SwitchListTile.adaptive(
                    value: settings.notifies(id),
                    onChanged: (bool value) =>
                        repo.setNotification(settings, id, enabled: value),
                    activeThumbColor: AppColors.gold,
                    contentPadding: EdgeInsets.zero,
                    secondary: Icon(id.icon, size: 19, color: AppColors.mist),
                    title: Text(id.label, style: AppType.titleSm),
                  ),
              ],
            ),
          ),
          const SizedBox(height: Insets.md),

          // Before and after the adhan. The adhan call itself is not optional
          // here — turning a prayer off above already silences all three.
          NightCard(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.lg,
              vertical: Insets.xs,
            ),
            child: Column(
              children: <Widget>[
                SwitchListTile.adaptive(
                  value: settings.remindBefore,
                  onChanged: (bool v) =>
                      repo.save(settings.copyWith(remindBefore: v)),
                  activeThumbColor: AppColors.gold,
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.schedule_rounded,
                    size: 19,
                    color: AppColors.mist,
                  ),
                  title: Text('Before the adhan', style: AppType.titleSm),
                  subtitle: Text(
                    'A moment to get ready',
                    style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                  ),
                ),
                if (settings.remindBefore)
                  _Minutes(
                    choices: PrayerSettings.beforeChoices,
                    value: settings.beforeMinutes,
                    onPick: (int m) =>
                        repo.save(settings.copyWith(beforeMinutes: m)),
                  ),
                const Divider(color: AppColors.navyLine, height: 1),
                SwitchListTile.adaptive(
                  value: settings.remindAfter,
                  onChanged: (bool v) =>
                      repo.save(settings.copyWith(remindAfter: v)),
                  activeThumbColor: AppColors.gold,
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(
                    Icons.history_rounded,
                    size: 19,
                    color: AppColors.mist,
                  ),
                  title: Text('After, if not prayed', style: AppType.titleSm),
                  subtitle: Text(
                    'Withdrawn the moment you confirm',
                    style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                  ),
                ),
                if (settings.remindAfter)
                  _Minutes(
                    choices: PrayerSettings.afterChoices,
                    value: settings.afterMinutes,
                    onPick: (int m) =>
                        repo.save(settings.copyWith(afterMinutes: m)),
                  ),
              ],
            ),
          ),
          // Android only, and the most common reason a reminder never comes.
          // The alarm is booked correctly and the phone decides not to run
          // it — Samsung's One UI puts apps to sleep by default — so the
          // notification simply does not arrive and nothing on screen
          // suggests why. iOS has no equivalent, and `unrestrictedProvider`
          // answers true there so this never appears.
          if (!(ref.watch(unrestrictedProvider).valueOrNull ?? true)) ...<Widget>[
            const SizedBox(height: Insets.md),
            NightCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _StepRow(
                    done: false,
                    title: 'Let reminders through',
                    body:
                        'This phone is allowed to put Layla Pro to sleep, and '
                        'a sleeping app cannot sound the adhan. Set battery '
                        'use to Unrestricted.',
                    actionLabel: 'Open',
                    onAction: () async {
                      await ref.read(batteryExemptionProvider).open();
                      ref.invalidate(unrestrictedProvider);
                    },
                  ),
                  const SizedBox(height: Insets.md),
                  const _Caveat(
                    text:
                        'On Samsung there is a second switch: Settings → '
                        'Battery → Background usage limits → make sure Layla '
                        'Pro is not in "Sleeping apps" or "Deep sleeping '
                        'apps". Both have to be right or the reminders arrive '
                        'late, or not at all.',
                    tone: AppColors.amber,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: Insets.md),
          TextButton.icon(
            onPressed: () async {
              final bool granted = await ref
                  .read(notificationServiceProvider)
                  .requestPermissions();
              if (!context.mounted) return;
              granted
                  ? context.showSuccess('Reminders are enabled.')
                  : context.showMessage(
                      'Reminders are blocked in your system settings.',
                    );
            },
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: const Text('Check notification permission'),
          ),
          TextButton.icon(
            onPressed: () async {
              final List<String> pending = await ref
                  .read(notificationServiceProvider)
                  .pendingSummary();
              if (!context.mounted) return;
              context.showMessage(
                pending.isEmpty
                    ? 'Nothing is scheduled. Reminders are queued when Layla Pro '
                          'opens, and reinstalling clears them.'
                    : '${pending.length} scheduled:\n${pending.join('\n')}',
              );
            },
            icon: const Icon(Icons.event_note_outlined, size: 18),
            label: const Text("What's scheduled?"),
          ),
          TextButton.icon(
            onPressed: () async {
              final bool granted = await ref
                  .read(notificationServiceProvider)
                  .requestPermissions();
              if (!context.mounted) return;
              if (!granted) {
                context.showMessage(
                  'Reminders are blocked in your system settings, so the '
                  'adhan cannot play.',
                );
                return;
              }
              await ref.read(notificationServiceProvider).sendTestAdhan();
              if (!context.mounted) return;
              context.showSuccess(
                Platform.isIOS
                    ? 'The adhan will sound in 5 seconds. Lock your phone to '
                          'hear it as you would at a prayer time — and check '
                          'the ring switch is not on silent.'
                    : 'The adhan will sound in 5 seconds. Lock your phone to '
                          'hear it as you would at a prayer time — and check '
                          'your phone is not on silent or in Do Not Disturb.',
              );
            },
            icon: const Icon(Icons.volume_up_outlined, size: 18),
            label: const Text('Test the adhan'),
          ),
          TextButton.icon(
            onPressed: () async {
              final NotificationService service = ref.read(
                notificationServiceProvider,
              );
              final bool granted = await service.requestPermissions();
              if (!context.mounted) return;
              if (!granted) {
                context.showMessage(
                  'Reminders are blocked in your system settings.',
                );
                return;
              }
              final String label = await service.sendTestPrayer();
              if (!context.mounted) return;
              context.showSuccess(
                'A $label reminder will arrive in 5 seconds, with its verse. '
                'Tap again for the next prayer.',
              );
            },
            icon: const Icon(Icons.notifications_outlined, size: 18),
            label: const Text('Test a prayer reminder'),
          ),
          const SizedBox(height: Insets.xl),
          const SectionHeader(label: 'Reminder sound'),
          const SoundPicker(),
          const SizedBox(height: Insets.xl),
          const SectionHeader(label: 'Prayer focus'),
          NightCard(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: SwitchListTile.adaptive(
              value: settings.lockEnabled,
              onChanged: (bool value) =>
                  repo.setLockEnabled(settings, enabled: value),
              activeThumbColor: AppColors.gold,
              contentPadding: EdgeInsets.zero,
              title: Text('Open focus at prayer time', style: AppType.titleSm),
              subtitle: Text(
                'A 30-minute full-screen window with no navigation, held open '
                'until you confirm with the two steps.',
                style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
              ),
            ),
          ),
          // The Live Activity is an iOS thing. Android's nearest relative
          // is an ongoing notification, which is not built, so the switch is
          // not offered there.
          if (Have.liveActivity) ...<Widget>[
            const SizedBox(height: Insets.xl),
            const SectionHeader(label: 'Lock Screen'),
            NightCard(
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              child: SwitchListTile.adaptive(
                value: ref.watch(liveActivityEnabledProvider),
                onChanged: (bool value) => ref
                    .read(liveActivityEnabledProvider.notifier)
                    .set(enabled: value),
                activeThumbColor: AppColors.gold,
                contentPadding: EdgeInsets.zero,
                title: Text('Live Activity', style: AppType.titleSm),
                subtitle: Text(
                  'The next prayer and a live countdown on the Lock Screen '
                  'and in the Dynamic Island. Its ticking uses some battery; '
                  'turn it off and it disappears straight away.',
                  style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                ),
              ),
            ),
          ],
          const SizedBox(height: Insets.xl),
          SectionHeader(
            // Android does not pause anything — it comes back over what you
            // opened — so calling the section "pausing" promised the wrong
            // mechanism before the card underneath had a chance to explain.
            label: Have.enforcedAppLock
                ? 'Pausing other apps'
                : 'Other apps during prayer',
          ),
          lock.when(
            loading: () => const SizedBox(
              height: 90,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object error, StackTrace stack) =>
                const _NoNativeLockCard(),
            data: (LockPermissions permissions) => switch (permissions.kind) {
              LockKind.androidSoftLock => const _AndroidSoftLockCard(),
              LockKind.iosScreenTime => const _ScreenTimeCard(),
              LockKind.none => const _NoNativeLockCard(),
            },
          ),
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}

/// Shared header: the master toggle plus a one-line status.
class _LockToggle extends ConsumerWidget {
  const _LockToggle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool enabled = ref.watch(appBlockingEnabledProvider);
    return SwitchListTile.adaptive(
      value: enabled,
      onChanged: (bool value) async {
        await ref.read(appBlockingEnabledProvider.notifier).set(enabled: value);
        ref.invalidate(lockPermissionsProvider);
      },
      activeThumbColor: AppColors.gold,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: AppType.titleSm),
      subtitle: Text(
        subtitle,
        style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
      ),
    );
  }
}

/// iOS — Apple's Screen Time shield. A real block, once the user grants it.
///
/// Laid out as: master switch → what to block → which prayers, so the two
/// questions a user actually has ("what gets blocked" and "when") are answered
/// in that order rather than buried in permission plumbing.
class _ScreenTimeCard extends ConsumerWidget {
  const _ScreenTimeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LockPermissions permissions =
        ref.watch(lockPermissionsProvider).valueOrNull ??
        const LockPermissions();
    final bool enabled = ref.watch(appBlockingEnabledProvider);
    final PrayerLockPlatform platform = ref.watch(prayerLockPlatformProvider);
    final PrayerSettings settings = ref.watch(prayerSettingsProvider);
    final PrayerSettingsRepository repo = ref.watch(
      prayerSettingsRepositoryProvider,
    );

    return NightCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Insets.lg),
            child: _LockToggle(
              title: 'Block apps during prayer',
              subtitle: 'Apps block automatically at each prayer time',
            ),
          ),

          // What the OS actually thinks, rather than what the toggle claims.
          //
          // "It is switched on but nothing blocks" is four different faults
          // wearing the same face: the preference not saved, Screen Time not
          // authorised, no apps picked, or the windows never handed over. They
          // are fixed in four different places and look identical from the
          // outside, so the state is put on screen instead of guessed at.
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.lg,
              0,
              Insets.lg,
              Insets.md,
            ),
            child: Wrap(
              spacing: Insets.sm,
              runSpacing: 4,
              children: <Widget>[
                _Flag(label: 'Saved', on: enabled),
                _Flag(label: 'Prayer focus', on: settings.lockEnabled),
                _Flag(label: 'Screen Time', on: permissions.authorized),
                _Flag(
                  label: 'Apps chosen',
                  on:
                      !settings.blockScope.needsSelection ||
                      permissions.hasSelection,
                ),
                _Flag(
                  label: '${settings.blockingCount} of 5 prayers',
                  on: settings.blockingCount > 0,
                ),
              ],
            ),
          ),
          if (enabled) ...<Widget>[
            const Divider(height: 1),
            const _SubHeader(label: 'What to block'),
            RadioGroup<BlockScope>(
              groupValue: settings.blockScope,
              onChanged: (BlockScope? scope) async {
                if (scope == null) return;
                await repo.setBlockScope(settings, scope);
                // The picker is the point of these two options — open it
                // straight away rather than making the user hunt for it.
                if (scope.needsSelection && permissions.authorized) {
                  await platform.chooseApps();
                }
                ref.invalidate(lockPermissionsProvider);
              },
              child: Column(
                children: <Widget>[
                  for (final BlockScope scope in BlockScope.values)
                    RadioListTile<BlockScope>(
                      value: scope,
                      activeColor: AppColors.gold,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: Insets.lg,
                      ),
                      title: Text(scope.label, style: AppType.titleSm),
                      subtitle: Text(
                        scope.description,
                        style: AppType.bodySm.copyWith(
                          color: AppColors.mistFaint,
                        ),
                      ),
                      secondary: Icon(
                        switch (scope) {
                          BlockScope.everything => Icons.apps_rounded,
                          BlockScope.specificApps => Icons.grid_view_rounded,
                          BlockScope.categories => Icons.layers_rounded,
                        },
                        size: 19,
                        color: AppColors.mist,
                      ),
                    ),
                ],
              ),
            ),
            if (settings.blockScope.needsSelection)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.lg,
                  0,
                  Insets.lg,
                  Insets.md,
                ),
                child: GhostButton(
                  label: permissions.hasSelection
                      ? 'Change what is blocked'
                      : 'Choose what to block',
                  icon: Icons.tune_rounded,
                  onPressed: permissions.authorized
                      ? () async {
                          await platform.chooseApps();
                          ref.invalidate(lockPermissionsProvider);
                        }
                      : null,
                ),
              ),
            const Divider(height: 1),
            _SubHeader(
              label: 'Active for',
              trailing:
                  '${settings.blockingCount} of '
                  '${PrayerId.obligatory.length}',
            ),
            for (final PrayerId id in PrayerId.obligatory)
              SwitchListTile.adaptive(
                value: settings.blocks(id),
                onChanged: (bool value) =>
                    repo.setBlocking(settings, id, enabled: value),
                activeThumbColor: AppColors.gold,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                ),
                secondary: Icon(id.icon, size: 19, color: AppColors.mist),
                title: Text(id.label, style: AppType.titleSm),
              ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(Insets.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _StepRow(
                    done: permissions.authorized,
                    title: 'Allow Screen Time',
                    body:
                        'Apple asks once. You can withdraw it any time in '
                        'Settings → Screen Time.',
                    actionLabel: 'Allow',
                    onAction: () async {
                      final String? failure = await platform
                          .requestAuthorization();
                      ref.invalidate(lockPermissionsProvider);
                      if (!context.mounted) return;
                      failure == null
                          ? context.showSuccess('Screen Time access granted.')
                          : context.showMessage(failure);
                    },
                  ),
                  const SizedBox(height: Insets.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: permissions.isComplete
                          ? () async {
                              final DateTime? endsAt = await platform
                                  .startTestWindow();
                              if (!context.mounted) return;
                              if (endsAt == null) {
                                context.showMessage(
                                  'A test block could not be started on this '
                                  'device.',
                                );
                                return;
                              }
                              // The report, not a reassurance. "Blocking now"
                              // was printed three times while nothing was
                              // being blocked.
                              final Map<String, Object?>? report =
                                  lastSelfTestReport;
                              final bool shielded =
                                  report?['shieldCategories'] == true ||
                                  (report?['shieldApps'] as int? ?? 0) > 0;
                              if (report != null && !shielded) {
                                context.showMessage(
                                  'The shield did not take. '
                                  'Screen Time: ${report['authorised']}, '
                                  'scope: ${report['scope']}, '
                                  'app group: ${report['appGroup']}, '
                                  'selection: ${report['selection']}.',
                                );
                                return;
                              }
                              context.showSuccess(
                                'Blocking now. Leave Layla Pro and try another app '
                                '— it should be shielded. It unblocks on its '
                                'own at ${Fmt.time(endsAt)}, with nothing to '
                                'tap.',
                              );
                            }
                          : null,
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      label: const Text('Test the block (15 minutes)'),
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: permissions.authorized
                          ? () async {
                              final DateTime? at = await platform
                                  .startTriggerTest();
                              if (!context.mounted) return;
                              at == null
                                  ? context.showMessage(
                                      'A trigger test could not be scheduled.',
                                    )
                                  : context.showSuccess(
                                      'Scheduled for ${Fmt.time(at)}. Close '
                                      'Layla Pro and wait — iOS should raise the '
                                      'shield on its own. That is the part a '
                                      'real prayer depends on.',
                                    );
                            }
                          : null,
                      icon: const Icon(Icons.timer_outlined, size: 18),
                      label: const Text('Test the real trigger (2 minutes)'),
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _testMatScanner(context, ref),
                      icon: const Icon(
                        Icons.center_focus_strong_outlined,
                        size: 18,
                      ),
                      label: const Text('Test the prayer-mat scanner'),
                    ),
                  ),
                  const SizedBox(height: Insets.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _testMatPhoto(context, ref),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Score a single photo'),
                    ),
                  ),
                  const SizedBox(height: Insets.lg),
                  _Caveat(
                    text: permissions.isComplete
                        ? 'Apps block for 30 minutes at each prayer time — even '
                              'when Layla Pro is closed — then unblock on their own. '
                              'Confirming the prayer is what keeps your streak, '
                              'not what unlocks your phone. Phone, Messages and '
                              'Settings are never blocked; Apple does not allow '
                              'it, and emergencies happen.'
                        : 'Screen Time access is still needed before anything '
                              'is blocked. Until then Layla Pro opens the focus '
                              'screen and still will not count an unconfirmed '
                              'prayer.',
                    tone: permissions.isComplete
                        ? AppColors.emerald
                        : AppColors.amber,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small uppercase divider label, with an optional "3 of 5" on the right.
/// One condition the blocker depends on, and whether it holds.
class _Flag extends StatelessWidget {
  const _Flag({required this.label, required this.on});

  final String label;
  final bool on;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: on ? AppColors.emerald : AppColors.rose),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          on ? Icons.check_rounded : Icons.close_rounded,
          size: 12,
          color: on ? AppColors.emerald : AppColors.rose,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppType.bodySm.copyWith(
            fontSize: 11,
            color: on ? AppColors.mist : AppColors.rose,
          ),
        ),
      ],
    ),
  );
}

/// Three fixed choices, as chips.
class _Minutes extends StatelessWidget {
  const _Minutes({
    required this.choices,
    required this.value,
    required this.onPick,
  });

  final List<int> choices;
  final int value;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Insets.md, left: 34),
    child: Row(
      children: <Widget>[
        for (final int m in choices)
          Padding(
            padding: const EdgeInsets.only(right: Insets.sm),
            child: GestureDetector(
              onTap: () => onPick(m),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: Insets.lg,
                  vertical: Insets.sm,
                ),
                decoration: BoxDecoration(
                  color: m == value
                      ? AppColors.navyElevated
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: m == value ? AppColors.gold : AppColors.navyLine,
                  ),
                ),
                child: Text(
                  '$m min',
                  style: AppType.bodySm.copyWith(
                    color: m == value ? AppColors.gold : AppColors.mistFaint,
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _SubHeader extends StatelessWidget {
  const _SubHeader({required this.label, this.trailing});

  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.lg,
        Insets.lg,
        Insets.lg,
        Insets.sm,
      ),
      child: Row(
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: AppType.label.copyWith(color: AppColors.gold),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
            ),
        ],
      ),
    );
  }
}

/// Android — best-effort, and the card says so plainly.
class _AndroidSoftLockCard extends ConsumerWidget {
  const _AndroidSoftLockCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LockPermissions permissions =
        ref.watch(lockPermissionsProvider).valueOrNull ??
        const LockPermissions();
    final bool enabled = ref.watch(appBlockingEnabledProvider);
    final PrayerLockPlatform platform = ref.watch(prayerLockPlatformProvider);

    return NightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _LockToggle(
            title: 'Return me to Layla Pro during prayer',
            subtitle:
                'When you open another app during a prayer window, Layla Pro brings '
                'the focus screen back over it.',
          ),
          if (enabled) ...<Widget>[
            const Divider(height: Insets.xl),
            Text(
              'This needs two special permissions that you grant in Android '
              'Settings. Layla Pro uses them only while a prayer window is open, '
              'and never records which apps you use.',
              style: AppType.bodySm.copyWith(
                color: AppColors.mist,
                height: 1.5,
              ),
            ),
            const SizedBox(height: Insets.lg),
            _StepRow(
              done: permissions.usageAccess,
              title: 'Usage access',
              body:
                  'Lets Layla Pro notice that a different app came to the front.',
              actionLabel: 'Grant',
              onAction: () async {
                await platform.requestUsageAccess();
                ref.invalidate(lockPermissionsProvider);
              },
            ),
            const SizedBox(height: Insets.md),
            _StepRow(
              done: permissions.overlay,
              title: 'Display over other apps',
              body: 'Lets Layla Pro show the focus reminder on top.',
              actionLabel: 'Grant',
              onAction: () async {
                await platform.requestOverlay();
                ref.invalidate(lockPermissionsProvider);
              },
            ),
            const SizedBox(height: Insets.md),

            // Without this the feature cannot do anything at all: the service
            // only covers an app that is in the chosen set, and until now
            // there was no way on Android to choose one. Switched on, both
            // permissions granted, and nothing would ever happen.
            _StepRow(
              done: ref.watch(blockedAppCountProvider).valueOrNull != null &&
                  ref.watch(blockedAppCountProvider).valueOrNull! > 0,
              title: 'Apps to pause',
              body:
                  'Pick the ones that take the ten minutes you meant to pray '
                  'in. Nothing is paused until you do.',
              actionLabel: 'Choose',
              onAction: () async {
                await context.push(Routes.pausedApps);
                ref.invalidate(blockedAppCountProvider);
              },
            ),

            const SizedBox(height: Insets.md),

            // The iPhone card has had this from the start and this one had
            // nothing, so the only way to find out whether the focus worked
            // on Android was to wait for a real prayer, open something else
            // and hope. Nobody does that, which is why nobody had ever
            // watched it engage.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: permissions.isComplete
                    ? () async {
                        final DateTime? endsAt = await platform
                            .startTestWindow();
                        if (!context.mounted) return;
                        context.showMessage(
                          endsAt == null
                              ? 'The focus could not start. Check both '
                                    'permissions above.'
                              : 'Focus on for two minutes. Open another app '
                                    'and Layla Pro should come back over it.',
                        );
                      }
                    : null,
                icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                label: const Text('Try it for two minutes'),
                style: TextButton.styleFrom(foregroundColor: AppColors.gold),
              ),
            ),

            const SizedBox(height: Insets.sm),

            // The mat scanner's own test buttons, which used to sit only on
            // the iPhone card — reasonably, since until the encoder was
            // ported there was nothing on Android to test. There is now, and
            // these are the only way to find out what a photo actually
            // scored.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _testMatScanner(context, ref),
                icon: const Icon(
                  Icons.center_focus_strong_outlined,
                  size: 18,
                ),
                label: const Text('Test the prayer-mat scanner'),
                style: TextButton.styleFrom(foregroundColor: AppColors.gold),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _testMatPhoto(context, ref),
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: const Text('Score a single photo'),
                style: TextButton.styleFrom(foregroundColor: AppColors.gold),
              ),
            ),

            const SizedBox(height: Insets.sm),
            const _Caveat(
              text:
                  'Even with both granted, this is best-effort. Android can '
                  'stop the service to save battery, and you can always leave, '
                  'force stop Layla Pro, or turn this off. Your streak is the real '
                  'accountability — not the lock.',
              tone: AppColors.amber,
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown when this build has no native lock module — an iOS build without the
/// Family Controls entitlement, or any other platform.
class _NoNativeLockCard extends StatelessWidget {
  const _NoNativeLockCard();

  @override
  Widget build(BuildContext context) {
    return NightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.info_outline_rounded,
                size: 20,
                color: AppColors.goldSoft,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Text(
                  'Not available on this device',
                  style: AppType.titleSm,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            'Layla Pro cannot pause other apps here.\n\n'
            'What you still get: a reminder when each prayer begins, a '
            'full-screen focus window with no way out except confirming, and a '
            'prayer that simply does not count until both steps are done.',
            style: AppType.bodySm.copyWith(color: AppColors.mist, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.done,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final bool done;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 19,
          color: done ? AppColors.emerald : AppColors.mistFaint,
        ),
        const SizedBox(width: Insets.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: AppType.titleSm),
              const SizedBox(height: 2),
              Text(
                body,
                style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

/// Opens the real Step 2 scanner, without waiting for a prayer.
///
/// The same viewfinder a prayer goes through, so what is tested here is what
/// actually gates a confirmation — and then the score is shown, which the
/// scanner itself never does.
///
/// Note what a timeout means here: the scanner only ever keeps a photo once it
/// has seen a mat, so running out of time *is* the rejection. Pointing this at
/// a carpet and watching the thirty seconds expire is the negative test.
Future<void> _testMatScanner(BuildContext context, WidgetRef ref) async {
  final XFile? shot = await scanForPrayerMat(context);
  if (!context.mounted) return;
  if (shot == null) {
    context.showMessage(
      'Nothing was scanned. The scanner keeps a photo only once it sees a '
      'mat, so this is what a rejection looks like.',
    );
    return;
  }
  await _reportMatScore(context, ref, shot);
}

/// Scores one photo taken the old way, with no scanner in between.
///
/// Kept alongside the scanner because it is the only way to get a number out
/// of something the scanner would refuse. The scanner never captures a carpet,
/// so it can never tell you *how far* from passing that carpet was — and that
/// distance is the whole question when the threshold needs moving.
Future<void> _testMatPhoto(BuildContext context, WidgetRef ref) async {
  final XFile? shot = await ref
      .read(proofRepositoryProvider)
      .capture(source: ImageSource.camera);
  if (shot == null || !context.mounted) return;
  await _reportMatScore(context, ref, shot);
}

/// Shows the verdict *and* the raw score.
///
/// The threshold is -0.045, so a photo at -0.04 passed by a hair while one at
/// +0.09 passed comfortably, and only the number tells those apart. If the
/// check ever rejects a real mat, that number is the useful thing to report
/// back.
Future<void> _reportMatScore(
  BuildContext context,
  WidgetRef ref,
  XFile shot,
) async {
  final ({MatVerdict verdict, double? margin, String detail}) seen = await ref
      .read(matVisionProvider)
      .examine(shot.path);
  if (!context.mounted) return;

  final String score = seen.margin == null
      ? 'no score — the encoder is missing from this build, so it fell back '
            'to generic labels (${seen.detail})'
      : 'score ${seen.margin! >= 0 ? '+' : ''}'
            '${seen.margin!.toStringAsFixed(3)}, threshold -0.045';

  switch (seen.verdict) {
    case MatVerdict.looksRight:
      context.showSuccess('Accepted — this would confirm a prayer. $score');
    case MatVerdict.looksWrong:
      context.showMessage('Rejected as not a prayer mat. $score');
    case MatVerdict.unsure:
      context.showMessage(
        'Not sure, so it would let this through rather than block you. $score',
      );
  }
}

class _Caveat extends StatelessWidget {
  const _Caveat({required this.text, required this.tone});

  final String text;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.md),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: tone.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: AppType.bodySm.copyWith(color: AppColors.mist, height: 1.5),
      ),
    );
  }
}
