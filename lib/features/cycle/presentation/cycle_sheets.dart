import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';

/// Asks before the pause begins, and says plainly what it will do.
///
/// A sheet rather than a straight toggle because four separate things change
/// at once — nothing is recorded, reminders stop, the streak is held, nothing
/// is shared — and three of those are invisible until they are missed. Someone
/// should be able to read what they are turning on before they turn it on,
/// not infer it from a week of silence.
Future<bool?> showCycleStartSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navy,
    builder: (BuildContext context) => const _CycleStartSheet(),
  );
}

/// Asks before the pause ends.
///
/// Ending it is one tap away on a card someone scrolls past every day, and a
/// mis-tap would put reminders, the shield and the prayer choices back in the
/// middle of a week when they are not wanted.
Future<bool?> showCycleEndSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navy,
    builder: (BuildContext context) => const _CycleEndSheet(),
  );
}

class _CycleStartSheet extends StatelessWidget {
  const _CycleStartSheet();

  @override
  Widget build(BuildContext context) {
    return const _SheetFrame(
      title: 'Pause prayers for these days?',
      // The ruling first, in plain words, because it is the thing the feature
      // exists to honour and the thing an app can most easily get wrong. A
      // woman does not pray during her period and those prayers are not made
      // up afterwards — the fast is, the prayer is not.
      intro:
          'While you are on your period you do not pray, and these prayers '
          'are not made up afterwards.',
      rows: <_SheetRow>[
        _SheetRow(
          icon: Icons.check_circle_outline_rounded,
          positive: true,
          title: 'Nothing is owed',
          body:
              'These prayers are not recorded and never counted as missed. '
              'There is nothing to make up when it ends.',
        ),
        _SheetRow(
          icon: Icons.notifications_off_outlined,
          positive: true,
          title: 'Reminders stop',
          body:
              'No prayer reminders, no nudges, and your other apps are not '
              'paused at prayer time.',
        ),
        _SheetRow(
          icon: Icons.local_fire_department_outlined,
          positive: true,
          title: 'Your streak is kept',
          body:
              'These days neither break your streak nor add to it. It waits '
              'where you left it.',
        ),
        _SheetRow(
          icon: Icons.visibility_off_outlined,
          positive: false,
          title: 'Nobody can tell',
          body:
              'Nothing is shared with friends, and nothing about this appears '
              'on your widgets or Lock Screen.',
        ),
      ],
      footer:
          'You decide when it ends. Layla Pro will never end it for you, and '
          'never assumes it has.',
      confirmLabel: 'Pause prayers',
      confirmIcon: Icons.pause_circle_outline_rounded,
      cancelLabel: 'Not now',
    );
  }
}

class _CycleEndSheet extends StatelessWidget {
  const _CycleEndSheet();

  @override
  Widget build(BuildContext context) {
    return const _SheetFrame(
      title: 'Resume prayers?',
      intro:
          'Do this once it has ended and you have made ghusl. The next prayer '
          'whose time is in is the one you pray.',
      rows: <_SheetRow>[
        _SheetRow(
          icon: Icons.play_circle_outline_rounded,
          positive: true,
          title: 'Everything comes back',
          body:
              'Reminders, the prayer choices and the shield return from the '
              'next prayer onwards.',
        ),
        _SheetRow(
          icon: Icons.history_toggle_off_rounded,
          positive: true,
          title: 'The paused days stay paused',
          body:
              'The days behind you keep their pause. Nothing from them is '
              'added back, and nothing is owed.',
        ),
      ],
      footer: 'You can pause again whenever you need to.',
      confirmLabel: 'Resume prayers',
      confirmIcon: Icons.play_arrow_rounded,
      cancelLabel: 'Stay paused',
    );
  }
}

/// One row of the sheet: an icon, what changes, and what that means.
class _SheetRow {
  const _SheetRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.positive,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Emerald for what is kept or restored, gold for what is withheld — the
  /// same reading as the map-consent and guest sheets, so the colour means the
  /// same thing everywhere in the app.
  final bool positive;
}

/// The shape both sheets share, so they stay siblings rather than cousins.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.title,
    required this.intro,
    required this.rows,
    required this.footer,
    required this.confirmLabel,
    required this.confirmIcon,
    required this.cancelLabel,
  });

  final String title;
  final String intro;
  final List<_SheetRow> rows;
  final String footer;
  final String confirmLabel;
  final IconData confirmIcon;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    // The reasons scroll; the two decisions do not. At 1.3x Dynamic Type on a
    // 375pt phone the four rows are taller than the sheet can grow, and with
    // the buttons inside the scroll view the sheet opened showing neither of
    // them — a decision sheet whose decisions are below the fold. So the
    // scroll view takes what room is left and the buttons are pinned under it.
    // Flexible rather than Expanded: a short sheet still sizes to its content
    // instead of stretching to the full screen.
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Insets.xl,
                  Insets.sm,
                  Insets.xl,
                  0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title, style: AppType.displaySm),
                    const SizedBox(height: Insets.sm),
                    Text(
                      intro,
                      style: AppType.bodySm.copyWith(color: AppColors.mist),
                    ),
                    const SizedBox(height: Insets.xl),
                    for (final _SheetRow row in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Insets.lg),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Icon(
                              row.icon,
                              size: 20,
                              color: row.positive
                                  ? AppColors.emerald
                                  : AppColors.gold,
                            ),
                            const SizedBox(width: Insets.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(row.title, style: AppType.titleSm),
                                  const SizedBox(height: 2),
                                  Text(
                                    row.body,
                                    style: AppType.bodySm.copyWith(
                                      color: AppColors.mistFaint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(Insets.md),
                      decoration: BoxDecoration(
                        color: AppColors.navyElevated.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(Radii.sm),
                      ),
                      child: Text(
                        footer,
                        style: AppType.bodySm.copyWith(color: AppColors.mist),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Insets.xl,
              Insets.xl,
              Insets.xl,
              Insets.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PrimaryButton(
                  label: confirmLabel,
                  icon: confirmIcon,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
                const SizedBox(height: Insets.sm),
                GhostButton(
                  label: cancelLabel,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
