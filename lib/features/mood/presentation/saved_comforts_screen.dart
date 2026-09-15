import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../application/mood_store.dart';
import '../domain/mood_comfort.dart';
import 'widgets/comfort_face.dart';

/// The passages someone chose to keep.
class SavedComfortsScreen extends ConsumerWidget {
  const SavedComfortsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(savedComfortsProvider);
    final SavedComforts store = ref.read(savedComfortsProvider.notifier);
    final List<Comfort> saved = store.comforts;

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
          Text('Saved', style: AppType.displayLg),
          const SizedBox(height: Insets.sm),
          Text(
            saved.isEmpty
                ? 'Nothing kept yet. The bookmark on any card keeps it here.'
                : 'What you chose to keep. It stays on this phone.',
            style: AppType.body.copyWith(color: AppColors.mist),
          ),
          const SizedBox(height: Insets.xl),
          for (final Comfort c in saved) ...<Widget>[
            ComfortFace(
              comfort: c,
              tone: _toneFor(c),
              minHeight: 0,
              trailing: CircleIconButton(
                icon: Icons.bookmark_remove_rounded,
                tooltip: 'Remove',
                onPressed: () {
                  HapticFeedback.selectionClick();
                  store.toggle(c);
                },
              ),
            ),
            const SizedBox(height: Insets.md),
          ],
          const SizedBox(height: Insets.xxl),
        ],
      ),
    );
  }

  Color _toneFor(Comfort c) {
    final List<Mood> moods = MoodComfort.moodsFor(c);
    return moods.isEmpty ? AppColors.gold : moods.first.tone;
  }
}
