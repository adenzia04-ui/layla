import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/data/auth_repository.dart';
import '../application/story_controller.dart';
import '../domain/story.dart';
import 'widgets/report_sheet.dart';
import 'widgets/story_card.dart';

class StoryDetailScreen extends ConsumerWidget {
  const StoryDetailScreen({super.key, required this.storyId});

  final String storyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Story?> story = ref.watch(storyProvider(storyId));
    final bool liked =
        ref.watch(hasLikedProvider(storyId)).valueOrNull ?? false;
    final String? myUid = ref.watch(authRepositoryProvider).uid;

    return NightScaffold(
      scrollable: true,
      ornamentHeight: 200,
      leading: CircleIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        onPressed: () => context.pop(),
      ),
      child: story.when(
        loading: () => const SizedBox(height: 400, child: LoadingView()),
        error: (Object error, StackTrace stack) => const SizedBox(
          height: 400,
          child: ErrorView(message: 'This story could not be loaded.'),
        ),
        data: (Story? s) {
          if (s == null || s.status != StoryStatus.published) {
            return const SizedBox(
              height: 400,
              child: EmptyView(
                icon: Icons.visibility_off_outlined,
                title: 'Story unavailable',
                body: 'It may have been removed or is being reviewed.',
              ),
            );
          }
          final bool isMine = myUid != null && myUid == s.uid;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: Insets.xxxl),
              Row(
                children: <Widget>[
                  Icon(s.mood.icon, size: 20, color: AppColors.goldSoft),
                  const SizedBox(width: Insets.sm),
                  Text(s.mood.label, style: AppType.titleSm),
                ],
              ),
              const SizedBox(height: Insets.md),
              Text(s.displayAuthor, style: AppType.displayMd),
              Text(
                Fmt.relative(s.createdAt),
                style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
              ),
              const SizedBox(height: Insets.xl),
              Text(
                s.body,
                style: AppType.body.copyWith(
                  color: AppColors.cream,
                  height: 1.7,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: Insets.xxl),
              Row(
                children: <Widget>[
                  Expanded(
                    child: GhostButton(
                      label: liked
                          ? 'Liked · ${s.likeCount}'
                          : 'Like · ${s.likeCount}',
                      icon: liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_outline_rounded,
                      onPressed: () => ref
                          .read(storyControllerProvider.notifier)
                          .toggleLike(s.id),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.lg),
              if (isMine)
                TextButton.icon(
                  onPressed: () async {
                    final bool ok = await ref
                        .read(storyControllerProvider.notifier)
                        .delete(s.id);
                    if (ok && context.mounted) {
                      context
                        ..showMessage('Story deleted.')
                        ..pop();
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete my story'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.rose),
                )
              else
                TextButton.icon(
                  onPressed: () async {
                    final ReportOutcome? outcome = await showReportSheet(
                      context,
                    );
                    if (outcome == null || !context.mounted) return;
                    final bool ok = await ref
                        .read(storyControllerProvider.notifier)
                        .report(
                          storyId: s.id,
                          reason: outcome.reason,
                          note: outcome.note,
                        );
                    if (ok && context.mounted) {
                      context.showSuccess('Reported for review.');
                    }
                  },
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  label: const Text('Report this story'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.mist),
                ),
              const SizedBox(height: Insets.xl),
              const StoriesDisclaimer(),
            ],
          );
        },
      ),
    );
  }
}
