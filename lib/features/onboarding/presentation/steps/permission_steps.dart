import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/permission_service.dart';
import '../../../../core/config/platform_features.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../prayer_lock/data/prayer_lock_platform.dart';
import '../../application/journey_controller.dart';
import '../../domain/journey_answers.dart';
import '../journey_step.dart';

/// The three reminders, shown before iOS is asked for permission to send them.
///
/// Apple's prompt appears exactly once per install. Someone who taps "Don't
/// Allow" on a dialog they did not expect can only undo it in Settings, and
/// most never will — so the reminders are shown first, and the prompt comes
/// after, from a button they chose to press.
class RemindersStep extends JourneyStep {
  const RemindersStep();

  @override
  String title(JourneyAnswers a) =>
      'I can call you three times for every prayer.';

  /// Always passable, and it has to be.
  ///
  /// Gating this on `remindersAllowed` deadlocked the journey: the only thing
  /// that sets that flag is the permission request, the request runs inside
  /// the footer button, and the button was disabled until the flag was set.
  /// The step could not be finished at all.
  ///
  /// The general rule it broke: a step may only gate its button on something
  /// the person can do *on that screen*. Anything the button itself performs
  /// must not be its own precondition.
  @override
  bool answered(JourneyAnswers a) => true;

  @override
  String label(JourneyAnswers a) =>
      a.remindersAllowed == null ? 'Allow reminders' : 'Next';

  @override
  Widget body(BuildContext context, WidgetRef ref, JourneyAnswers a) =>
      _Reminders(answers: a);
}

class _Reminders extends ConsumerWidget {
  const _Reminders({required this.answers});

  final JourneyAnswers answers;

  static const List<({String title, String body})> _preview =
      <({String title, String body})>[
        (title: 'Asr is in 10 minutes', body: 'A moment to get ready'),
        (title: 'It is time to pray Asr', body: 'Layla Pro is with you'),
        (title: 'Asr was 30 minutes ago', body: 'It is not too late'),
      ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool? allowed = answers.remindersAllowed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final ({String title, String body}) n in _preview)
          Container(
            margin: const EdgeInsets.only(bottom: Insets.sm),
            padding: const EdgeInsets.all(Insets.md),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.navyLine),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  height: 38,
                  width: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.navyElevated,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.mosque_rounded,
                    size: 19,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(n.title, style: AppType.titleSm),
                      Text(
                        n.body,
                        style: AppType.bodySm.copyWith(
                          color: AppColors.mistFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'now',
                  style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
                ),
              ],
            ),
          ),
        const SizedBox(height: Insets.xl),
        Text(
          'Allah SWT said:',
          style: AppType.titleSm.copyWith(color: AppColors.gold),
        ),
        const SizedBox(height: Insets.xs),
        Text(
          '“So remind, if the reminder should benefit.”',
          style: AppType.body.copyWith(color: AppColors.cream),
        ),
        Text(
          'Surah Al-A\'la 87:9',
          style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
        ),
        if (allowed == false) ...<Widget>[
          const SizedBox(height: Insets.lg),
          Text(
            'Reminders are off. You can turn them on in Settings whenever '
            'you like — everything else still works.',
            style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
          ),
        ],
      ],
    );
  }
}

/// Asks iOS on the step's behalf, from the footer button.
///
/// Kept apart from the widget so the host can call it before advancing: the
/// button says "Allow reminders", and it would be a small lie for it to move
/// on without having asked.
Future<void> askForReminders(WidgetRef ref) async {
  final PermissionOutcome outcome = await ref
      .read(permissionServiceProvider)
      .requestNotifications();
  ref.read(journeyProvider.notifier).setRemindersAllowed(outcome.isGranted);
}

/// Whether to shut the noisy apps while a prayer window is open.
class PauseAppsStep extends JourneyStep {
  const PauseAppsStep();

  @override
  String title(JourneyAnswers a) => Have.enforcedAppLock
      ? 'Shall I pause your apps when it is time to pray?'
      : 'Shall I bring you back when it is time to pray?';

  @override
  bool answered(JourneyAnswers a) => a.wantsAppPause != null;

  @override
  bool get advancesOnTap => true;

  @override
  Widget body(BuildContext context, WidgetRef ref, JourneyAnswers a) {
    final JourneyController c = ref.read(journeyProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          // Android cannot hold another app closed — nothing can — so what
          // is offered there is what is actually delivered: the prayer
          // screen comes back over whatever was opened. Promising a shield
          // and shipping a nudge is how an app earns a one-star review that
          // is entirely fair.
          Have.enforcedAppLock
              ? 'The ones that swallow the ten minutes you meant to pray in. '
                    'They come back the moment you have prayed.'
              : 'Open one of the apps that swallow the ten minutes you meant '
                    'to pray in, and Layla Pro comes back over it. You can '
                    'always step past it — it is a nudge, not a lock.',
          style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
        ),
        const SizedBox(height: Insets.xl),
        _PauseIllustration(),
        const SizedBox(height: Insets.xl),
        _Choice(
          // The question above already forks per platform; the answer did
          // not, so Android offered to "pause" apps it cannot pause.
          label: Have.enforcedAppLock ? 'Yes, pause them' : 'Yes, bring me back',
          selected: a.wantsAppPause == true,
          onTap: () => c.setWantsAppPause(true),
        ),
        const SizedBox(height: Insets.sm),
        _Choice(
          label: 'No, leave them be',
          selected: a.wantsAppPause == false,
          onTap: () => c.setWantsAppPause(false),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(Insets.lg),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? AppColors.navyElevated : AppColors.navy,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.navyLine,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Text(label, style: AppType.titleMd),
    ),
  );
}

/// A phone with its apps dimmed behind a shield.
///
/// Drawn rather than screenshotted: a picture of somebody's home screen dates
/// the moment an icon changes, and there is no good reason to ship other
/// companies' logos inside a prayer app.
class _PauseIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      height: 168,
      width: 116,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.navyLine, width: 2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 7,
            crossAxisSpacing: 7,
            physics: const NeverScrollableScrollPhysics(),
            children: <Widget>[
              for (int i = 0; i < 9; i++)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.navyLine.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
            ],
          ),
          Container(
            height: 46,
            width: 46,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.midnight,
            ),
            child: const Icon(
              Icons.mosque_rounded,
              color: AppColors.gold,
              size: 24,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Apple's Screen Time grant, and the app picker behind it.
///
/// Only reached by someone who has just said yes to pausing. Skipped on any
/// platform without the bridge, and skippable by anyone who changes their
/// mind at the dialog — a refused grant leaves the rest of the app untouched.
class ScreenTimeStep extends JourneyStep {
  const ScreenTimeStep();

  @override
  String title(JourneyAnswers a) => 'Two taps from Apple, then we are set.';

  /// iPhone only. This screen is about Apple's Screen Time, down to the
  /// words on it — an Android phone was being told it was "two taps from
  /// Apple" and then handed the message "Screen Time is only available on
  /// iOS" when it tapped. [AndroidFocusStep] asks Android for what Android
  /// actually needs.
  @override
  bool shows(JourneyAnswers a) =>
      a.wantsAppPause == true && Have.enforcedAppLock;

  /// Always passable. The grant lives with iOS, not here, and a journey that
  /// cannot be finished without it would trap anyone who says no.
  @override
  bool answered(JourneyAnswers a) => true;

  @override
  String label(JourneyAnswers a) => 'Continue';

  @override
  Widget body(BuildContext context, WidgetRef ref, JourneyAnswers a) =>
      const _ScreenTime();
}

class _ScreenTime extends ConsumerStatefulWidget {
  const _ScreenTime();

  @override
  ConsumerState<_ScreenTime> createState() => _ScreenTimeState();
}

class _ScreenTimeState extends ConsumerState<_ScreenTime> {
  bool _granted = false;
  bool _picked = false;
  bool _busy = false;

  Future<void> _grant() async {
    setState(() => _busy = true);
    final String? failure = await ref
        .read(prayerLockPlatformProvider)
        .requestAuthorization();
    if (!mounted) return;
    setState(() {
      _granted = failure == null;
      _busy = false;
    });
    // The reason belongs on screen here too — this is the step where most
    // people meet Screen Time for the first time.
    if (failure != null && mounted) context.showMessage(failure);
  }

  Future<void> _choose() async {
    setState(() => _busy = true);
    final bool ok = await ref.read(prayerLockPlatformProvider).chooseApps();
    if (!mounted) return;
    setState(() {
      _picked = ok;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Screen Time is how iOS lets an app dim another one. Apple keeps '
          'the list — Layla Pro is handed opaque tokens and never learns which '
          'apps you chose.',
          style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
        ),
        const SizedBox(height: Insets.xl),
        _Grant(
          step: '1',
          label: 'Allow Screen Time',
          done: _granted,
          busy: _busy,
          onTap: _granted ? null : _grant,
        ),
        const SizedBox(height: Insets.sm),
        _Grant(
          step: '2',
          label: 'Choose the apps to pause',
          done: _picked,
          busy: _busy,
          onTap: !_granted || _picked ? null : _choose,
        ),
        const SizedBox(height: Insets.lg),
        Text(
          'You can change either of these later, in Reminders & prayer focus.',
          style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
        ),
      ],
    );
  }
}

/// The Android half of the same question, asked in Android's own terms.
///
/// Two special accesses, both granted in Settings rather than in a dialog,
/// and neither of them Screen Time. Skippable like the Apple one: somebody
/// who says no here still has an app, and Reminders & prayer focus will ask
/// again whenever they want it.
class AndroidFocusStep extends JourneyStep {
  const AndroidFocusStep();

  @override
  String title(JourneyAnswers a) => 'Two permissions, granted in Settings.';

  @override
  bool shows(JourneyAnswers a) =>
      a.wantsAppPause == true && !Have.enforcedAppLock && Platform.isAndroid;

  @override
  bool answered(JourneyAnswers a) => true;

  @override
  String label(JourneyAnswers a) => 'Continue';

  @override
  Widget body(BuildContext context, WidgetRef ref, JourneyAnswers a) =>
      const _AndroidFocus();
}

class _AndroidFocus extends ConsumerStatefulWidget {
  const _AndroidFocus();

  @override
  ConsumerState<_AndroidFocus> createState() => _AndroidFocusState();
}

class _AndroidFocusState extends ConsumerState<_AndroidFocus>
    with WidgetsBindingObserver {
  bool _busy = false;
  LockPermissions _state = const LockPermissions();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-reads both grants whenever the app comes back to the front.
  ///
  /// Both are given in Settings, which means leaving the app and returning,
  /// and the answer is not readable the instant we return: the overlay grant
  /// reported as still missing for a second or so after it had been given,
  /// so the row sat there grey and the person had gone to Settings for
  /// nothing they could see.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    // Asked more than once, briefly. The grant lands in the system a moment
    // after the screen does.
    for (final int wait in <int>[0, 400, 1200]) {
      if (wait > 0) {
        await Future<void>.delayed(Duration(milliseconds: wait));
      }
      if (!mounted) return;
      final LockPermissions now = await ref
          .read(prayerLockPlatformProvider)
          .permissions();
      if (!mounted) return;
      setState(() => _state = now);
      if (now.usageAccess && now.overlay) return;
    }
  }

  Future<void> _ask(Future<void> Function() request) async {
    setState(() => _busy = true);
    await request();
    if (!mounted) return;
    setState(() => _busy = false);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final PrayerLockPlatform lock = ref.read(prayerLockPlatformProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Android has nothing like Screen Time, so Layla Pro does the '
          'nearest honest thing: it notices a paused app opening and covers '
          'it with a prayer screen. That needs two permissions you grant in '
          'Settings, and it never records which apps you use.',
          style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
        ),
        const SizedBox(height: Insets.xl),
        _Grant(
          step: '1',
          label: 'Usage access',
          done: _state.usageAccess,
          busy: _busy,
          onTap: _state.usageAccess
              ? null
              : () => _ask(lock.requestUsageAccess),
        ),
        const SizedBox(height: Insets.sm),
        _Grant(
          step: '2',
          label: 'Display over other apps',
          done: _state.overlay,
          busy: _busy,
          onTap: _state.overlay ? null : () => _ask(lock.requestOverlay),
        ),
        const SizedBox(height: Insets.lg),
        Text(
          'You choose which apps to pause in Reminders & prayer focus, and '
          'you can change either permission there or turn this off entirely.',
          style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
        ),
      ],
    );
  }
}

class _Grant extends StatelessWidget {
  const _Grant({
    required this.step,
    required this.label,
    required this.done,
    required this.busy,
    required this.onTap,
  });

  final String step;
  final String label;
  final bool done;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool live = onTap != null && !busy;
    return GestureDetector(
      onTap: live ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(Insets.lg),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: done ? AppColors.emerald : AppColors.navyLine,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              height: 26,
              width: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.emerald : AppColors.navyElevated,
              ),
              child: done
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppColors.midnight,
                    )
                  : Text(
                      step,
                      style: AppType.bodySm.copyWith(color: AppColors.mist),
                    ),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Text(
                label,
                style: AppType.titleSm.copyWith(
                  color: live || done ? AppColors.cream : AppColors.mistFaint,
                ),
              ),
            ),
            if (live)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mistFaint,
              ),
          ],
        ),
      ),
    );
  }
}
