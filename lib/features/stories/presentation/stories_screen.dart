import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/state_views.dart';
import '../application/story_controller.dart';
import '../domain/story.dart';
import 'widgets/report_sheet.dart';
import 'widgets/story_card.dart';

class StoriesScreen extends ConsumerWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Story>> feed = ref.watch(storyFeedProvider);

    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: AppBar(
        leading: CircleIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onPressed: () => context.pop(),
        ),
        title: Text('Tahajjud Stories', style: AppType.displaySm),
      ),
      // Lifted clear of the floating tab bar, which is drawn by the shell on
      // top of this screen and had been covering the button completely.
      // MediaQuery carries the bar's height, so screens pushed outside the
      // shell keep only the device inset and gain no phantom gap.
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.midnight,
          onPressed: () => context.push(Routes.storyCompose),
          icon: const Icon(Icons.edit_outlined),
          label: Text('Share', style: AppType.button),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.nightSky),
        child: feed.when(
          loading: () => const LoadingView(),
          error: (Object error, StackTrace stack) => ErrorView(
            message: 'Stories could not be loaded.',
            onRetry: () => ref.invalidate(storyFeedProvider),
          ),
          data: (List<Story> stories) => ListView(
            padding: const EdgeInsets.fromLTRB(
              Insets.page,
              Insets.sm,
              Insets.page,
              96,
            ),
            children: <Widget>[
              const StoriesDisclaimer(),
              const SizedBox(height: Insets.lg),
              if (stories.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: Insets.xxxl),
                  child: EmptyView(
                    icon: Icons.nights_stay_outlined,
                    title: 'No stories yet',
                    body:
                        'Be the first to share what praying Tahajjud was like '
                        'for you tonight.',
                  ),
                )
              else
                for (final Story story in stories)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Insets.md),
                    child: StoryCard(
                      story: story,
                      onTap: () => context.push(Routes.storyDetail(story.id)),
                      onLike: () => ref
                          .read(storyControllerProvider.notifier)
                          .toggleLike(story.id),
                      onReport: () async {
                        final ReportOutcome? outcome = await showReportSheet(
                          context,
                        );
                        if (outcome == null || !context.mounted) return;
                        final bool ok = await ref
                            .read(storyControllerProvider.notifier)
                            .report(
                              storyId: story.id,
                              reason: outcome.reason,
                              note: outcome.note,
                            );
                        if (ok && context.mounted) {
                          context.showSuccess(
                            'Thank you — this story has been reported for '
                            'review.',
                          );
                        }
                      },
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
