import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/notification_service.dart';
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

/// Reminders, the prayer focus window, and the native lock.
///
/// This screen is where Noor is honest about what each operating system will
/// and will not allow — see `docs/PRAYER_LOCK_LIMITATIONS.md`.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PrayerSettings settings = ref.watch(prayerSettingsProvider);
    final PrayerSettingsRepository repo =
        ref.watch(prayerSettingsRepositoryProvider);
    final AsyncValue<LockPermissions> lock =
        ref.watch(lockPermissionsProvider);

    return NightScaffold(
      scrollable: true,
      ornamentHeight: 180,
      title: 'Reminders & focus',
      leading: Padding(
        padding: const EdgeInsets.all(Insets.sm),
        child: CircleIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onPressed: () => context.pop(),
        ),
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
                    ? 'Nothing is scheduled. Reminders are queued when Layla '
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
                'The adhan will sound in 5 seconds. Lock your phone to hear '
                'it as you would at a prayer time — and check the ring '
                'switch is not on silent.',
              );
            },
            icon: const Icon(Icons.volume_up_outlined, size: 18),
            label: const Text('Test the adhan'),
          ),
          TextButton.icon(
            onPressed: () async {
              final NotificationService service =
                  ref.read(notificationServiceProvider);
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
          const SizedBox(height: Insets.xl),
          const SectionHeader(label: 'Pausing other apps'),
          lock.when(
            loading: () => const SizedBox(
              height: 90,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object error, StackTrace stack) => const _NoNativeLockCard(),
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
        await ref
            .read(appBlockingEnabledProvider.notifier)
            .set(enabled: value);
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
        ref.watch(lockPermissionsProvider).value ?? const LockPermissions();
    final bool enabled = ref.watch(appBlockingEnabledProvider);
    final PrayerLockPlatform platform = ref.watch(prayerLockPlatformProvider);
    final PrayerSettings settings = ref.watch(prayerSettingsProvider);
    final PrayerSettingsRepository repo =
        ref.watch(prayerSettingsRepositoryProvider);

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
                        style: AppType.bodySm
                            .copyWith(color: AppColors.mistFaint),
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
              trailing: '${settings.blockingCount} of '
                  '${PrayerId.obligatory.length}',
            ),
            for (final PrayerId id in PrayerId.obligatory)
              SwitchListTile.adaptive(
                value: settings.blocks(id),
                onChanged: (bool value) =>
                    repo.setBlocking(settings, id, enabled: value),
                activeThumbColor: AppColors.gold,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: Insets.lg),
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
                    body: 'Apple asks once. You can withdraw it any time in '
                        'Settings → Screen Time.',
                    actionLabel: 'Allow',
                    onAction: () async {
                      final bool granted =
                          await platform.requestAuthorization();
                      ref.invalidate(lockPermissionsProvider);
                      if (!context.mounted) return;
                      granted
                          ? context.showSuccess('Screen Time access granted.')
                          : context.showMessage(
                              'Screen Time access was not granted, so apps '
                              'will not be blocked.',
                            );
                    },
                  ),
                  const SizedBox(height: Insets.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: permissions.isComplete
                          ? () async {
                              final DateTime? endsAt =
                                  await platform.startTestWindow();
                              if (!context.mounted) return;
                              if (endsAt == null) {
                                context.showMessage(
                                  'A test block could not be started on this '
                                  'device.',
                                );
                                return;
                              }
                              context.showSuccess(
                                'Blocking now. Leave Layla and try another app '
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
                  const SizedBox(height: Insets.lg),
                  _Caveat(
                    text: permissions.isComplete
                        ? 'Apps block for 30 minutes at each prayer time — even '
                              'when Layla is closed — then unblock on their own. '
                              'Confirming the prayer is what keeps your streak, '
                              'not what unlocks your phone. Phone, Messages and '
                              'Settings are never blocked; Apple does not allow '
                              'it, and emergencies happen.'
                        : 'Screen Time access is still needed before anything '
                            'is blocked. Until then Layla opens the focus '
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
        ref.watch(lockPermissionsProvider).value ?? const LockPermissions();
    final bool enabled = ref.watch(appBlockingEnabledProvider);
    final PrayerLockPlatform platform = ref.watch(prayerLockPlatformProvider);

    return NightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _LockToggle(
            title: 'Return me to Layla during prayer',
            subtitle:
                'When you open another app during a prayer window, Layla brings '
                'the focus screen back over it.',
          ),
          if (enabled) ...<Widget>[
            const Divider(height: Insets.xl),
            Text(
              'This needs two special permissions that you grant in Android '
              'Settings. Layla uses them only while a prayer window is open, '
              'and never records which apps you use.',
              style: AppType.bodySm
                  .copyWith(color: AppColors.mist, height: 1.5),
            ),
            const SizedBox(height: Insets.lg),
            _StepRow(
              done: permissions.usageAccess,
              title: 'Usage access',
              body: 'Lets Layla notice that a different app came to the front.',
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
              body: 'Lets Layla show the focus reminder on top.',
              actionLabel: 'Grant',
              onAction: () async {
                await platform.requestOverlay();
                ref.invalidate(lockPermissionsProvider);
              },
            ),
            const SizedBox(height: Insets.lg),
            const _Caveat(
              text: 'Even with both granted, this is best-effort. Android can '
                  'stop the service to save battery, and you can always leave, '
                  'force stop Layla, or turn this off. Your streak is the real '
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
              const Icon(Icons.info_outline_rounded,
                  size: 20, color: AppColors.goldSoft,),
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
            'Layla cannot pause other apps here.\n\n'
            'What you still get: a reminder when each prayer begins, a '
            'full-screen focus window with no way out except confirming, and a '
            'prayer that simply does not count until both steps are done.',
            style: AppType.bodySm
                .copyWith(color: AppColors.mist, height: 1.55),
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
