import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../application/mood_store.dart';
import '../domain/mood_comfort.dart';

/// The lines written afterwards, newest first.
class MoodJournalScreen extends ConsumerWidget {
  const MoodJournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<JournalEntry> entries = ref.watch(moodJournalProvider);

    return NightScaffold(
      scrollable: true,
      ornamentHeight: 200,
      leading: CircleIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        onPressed: () => context.pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.xxxl),
          Text('Your journal', style: AppType.displayLg),
          const SizedBox(height: Insets.sm),
          Text(
            entries.isEmpty
                ? 'Nothing written yet. Each deck ends with a line to write, '
                      'if you want to.'
                : 'What you wrote afterwards. Only you can read this.',
            style: AppType.body.copyWith(color: AppColors.mist),
          ),
          const SizedBox(height: Insets.xl),
          for (final JournalEntry e in entries) ...<Widget>[
            _EntryCard(
              entry: e,
              comfort: e.comfortId == null
                  ? null
                  : MoodComfort.byId(e.comfortId!),
              onDelete: () {
                HapticFeedback.selectionClick();
                ref.read(moodJournalProvider.notifier).remove(e);
              },
            ),
            const SizedBox(height: Insets.md),
          ],
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onDelete, this.comfort});

  final JournalEntry entry;
  final Comfort? comfort;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Color tone = entry.mood.tone;
    return NightCard(
      borderColor: tone.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(entry.mood.icon, size: 16, color: tone),
              const SizedBox(width: Insets.sm),
              Text(
                entry.mood.label.toUpperCase(),
                style: AppType.label.copyWith(color: tone),
              ),
              const Spacer(),
              Text(
                '${Fmt.shortDate(entry.at)} · ${Fmt.time(entry.at)}',
                style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
              ),
              const SizedBox(width: Insets.xs),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.mistFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: Insets.sm),
          Text(
            entry.note,
            style: AppType.body.copyWith(color: AppColors.cream, height: 1.6),
          ),
          if (comfort != null) ...<Widget>[
            const SizedBox(height: Insets.md),
            Text(
              '“${comfort!.english}” — ${comfort!.reference}',
              style: AppType.bodySm.copyWith(
                color: AppColors.mist,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
