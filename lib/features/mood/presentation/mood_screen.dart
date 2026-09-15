import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../application/mood_store.dart';
import '../domain/mood_comfort.dart';
import 'widgets/touch_ripples.dart';

/// "How are you feeling?" — name a mood, and be taken to its deck.
///
/// Two doors in the corner, to what you kept and what you wrote, and below
/// the feelings a quiet strip of the last month. All of it lives on the
/// phone; nothing here is sent anywhere.
class MoodScreen extends ConsumerWidget {
  const MoodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<MoodPick> history = ref.watch(moodHistoryProvider);
    final int saved = ref.watch(savedComfortsProvider).length;

    return TouchRipples(
      child: NightScaffold(
        scrollable: true,
        ornamentHeight: 220,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: Insets.sm),
            Row(
              children: <Widget>[
                CircleIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  tooltip: 'Back',
                  onPressed: () => context.pop(),
                ),
                const Spacer(),
                CircleIconButton(
                  icon: saved > 0
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  tooltip: 'Saved',
                  onPressed: () => context.push(Routes.moodSaved),
                ),
                const SizedBox(width: Insets.sm),
                CircleIconButton(
                  icon: Icons.edit_note_rounded,
                  tooltip: 'Journal',
                  onPressed: () => context.push(Routes.moodJournal),
                ),
              ],
            ),
            const SizedBox(height: Insets.lg),
            Text('How are you feeling?', style: AppType.displayLg),
            const SizedBox(height: Insets.sm),
            Text(
              'Pick whatever is closest. Layla Pro will find you something to '
              'hold on to.',
              style: AppType.body.copyWith(color: AppColors.mist),
            ),
            const SizedBox(height: Insets.xl),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: Insets.md,
              crossAxisSpacing: Insets.md,
              childAspectRatio: 1.9,
              children: <Widget>[
                for (final Mood m in Mood.values)
                  _MoodChip(
                    mood: m,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(moodHistoryProvider.notifier).record(m);
                      context.push(Routes.moodDeck(m.name));
                    },
                  ),
              ],
            ),
            if (history.isNotEmpty) ...<Widget>[
              const SizedBox(height: Insets.xxl),
              const SectionHeader(label: 'The last month'),
              _MonthStrip(history: ref.read(moodHistoryProvider.notifier)),
            ],
            const SizedBox(height: Insets.xxl),
          ],
        ),
      ),
    );
  }
}

/// Thirty dots, one a day, each in the colour of what was felt.
class _MonthStrip extends StatelessWidget {
  const _MonthStrip({required this.history});

  final MoodHistory history;

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime.now();
    return NightCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (int i = 29; i >= 0; i--)
                _DayDot(
                  moods: history.on(today.subtract(Duration(days: i))),
                  isToday: i == 0,
                ),
            ],
          ),
          const SizedBox(height: Insets.md),
          Text(
            'Each dot is a day; the colour is the feeling you named. Only you '
            'can see this.',
            style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
          ),
        ],
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.moods, required this.isToday});

  final List<Mood> moods;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final Color? tone = moods.isEmpty ? null : moods.first.tone;
    return Tooltip(
      message: moods.isEmpty
          ? 'Nothing named'
          : moods.map((Mood m) => m.label).join(', '),
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: tone ?? AppColors.navyLine.withValues(alpha: 0.6),
          border: Border.all(
            color: isToday ? AppColors.gold : Colors.transparent,
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  const _MoodChip({required this.mood, required this.onTap});

  final Mood mood;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tone = mood.tone;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.navyElevated,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.navyLine),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.md),
          splashColor: tone.withValues(alpha: 0.18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Insets.md,
              vertical: Insets.sm,
            ),
            child: Row(
              children: <Widget>[
                Icon(mood.icon, size: 20, color: tone),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(mood.label, style: AppType.titleSm),
                      Text(
                        mood.hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.bodySm.copyWith(
                          fontSize: 11,
                          color: AppColors.mistFaint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
