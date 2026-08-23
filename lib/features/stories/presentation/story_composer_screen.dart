import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../application/story_controller.dart';
import '../domain/story.dart';
import 'widgets/story_card.dart';

class StoryComposerScreen extends ConsumerStatefulWidget {
  const StoryComposerScreen({super.key});

  @override
  ConsumerState<StoryComposerScreen> createState() =>
      _StoryComposerScreenState();
}

class _StoryComposerScreenState extends ConsumerState<StoryComposerScreen> {
  final TextEditingController _body = TextEditingController();
  StoryMood _mood = StoryMood.peaceful;
  bool _anonymous = false;

  static const List<String> _prompts = <String>[
    'How did you feel after praying tonight?',
    'What was on your mind while making dua?',
    'What made you get up tonight?',
    'What would you say to someone who finds it hard to wake up?',
  ];

  @override
  void initState() {
    super.initState();
    _body.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    FocusScope.of(context).unfocus();
    final String? id = await ref.read(storyControllerProvider.notifier).publish(
          body: _body.text,
          mood: _mood,
          anonymous: _anonymous,
        );
    if (id == null || !mounted) return;
    context
      ..showSuccess('Your story has been shared.')
      ..pop();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> state = ref.watch(storyControllerProvider);
    final int length = _body.text.trim().length;
    final bool canPublish = length >= 40 && length <= 1200;

    ref.listen<AsyncValue<void>>(storyControllerProvider,
        (AsyncValue<void>? previous, AsyncValue<void> next) {
      if (next.hasError && !next.isLoading) context.showError(next.error!);
    });

    // No MediaQuery surgery here any more: the route sits above the shell, so
    // there is no tab bar to make room for and the insets are the device's own.
    return NightScaffold(
      scrollable: true,
      ornamentHeight: 200,
      leading: Padding(
        padding: const EdgeInsets.all(Insets.sm),
        child: CircleIconButton(
          icon: Icons.close_rounded,
          onPressed: () => context.pop(),
        ),
      ),
      title: 'Share your story',
      // Pinned rather than sitting at the end of the scroll. The Scaffold
      // lifts this above the keyboard, so the one action the screen exists for
      // is always on screen instead of being something to go looking for.
      bottom: _ComposerAction(
        canPublish: canPublish,
        busy: state.isLoading,
        length: length,
        onPublish: _publish,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: Insets.xxxl),
          const StoriesDisclaimer(),
          const SizedBox(height: Insets.xl),
          Text(
            'HOW ARE YOU FEELING',
            style: AppType.label.copyWith(color: AppColors.gold),
          ),
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: <Widget>[
              for (final StoryMood mood in StoryMood.values)
                AppChip(
                  label: mood.label,
                  icon: mood.icon,
                  selected: _mood == mood,
                  onTap: () => setState(() => _mood = mood),
                ),
            ],
          ),
          const SizedBox(height: Insets.xl),
          Text(
            'YOUR EXPERIENCE',
            style: AppType.label.copyWith(color: AppColors.gold),
          ),
          const SizedBox(height: 6),
          // Guidance belongs before the writing, not after it — and keeping
          // the toggle as the last thing in the scroll removes the stretch
          // of faint text that read as an empty gap under it.
          Text(
            'Write about your own experience. Please avoid presenting '
            'anything as a guaranteed result of prayer or dua, and do not '
            "share other people's private details.",
            style: AppType.bodySm
                .copyWith(color: AppColors.mistFaint, height: 1.5),
          ),
          const SizedBox(height: Insets.md),
          TextField(
            controller: _body,
            // Smaller floor than before: with the keyboard up, a six-line
            // field left almost nothing of the screen for what comes after it.
            maxLines: 8,
            minLines: 4,
            maxLength: 1200,
            textCapitalization: TextCapitalization.sentences,
            // Return closes the keyboard rather than adding a line. A story is
            // a few sentences, and getting the keyboard out of the way matters
            // more here than paragraph breaks.
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            style: AppType.body.copyWith(color: AppColors.cream, height: 1.55),
            decoration: InputDecoration(
              hintText: _prompts[DateTime.now().day % _prompts.length],
              counterStyle: AppType.bodySm.copyWith(color: AppColors.mistFaint),
            ),
          ),
          const SizedBox(height: Insets.md),
          NightCard(
            padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
            child: SwitchListTile.adaptive(
              value: _anonymous,
              onChanged: (bool v) => setState(() => _anonymous = v),
              activeThumbColor: AppColors.gold,
              contentPadding: EdgeInsets.zero,
              title: Text('Share without my name', style: AppType.titleSm),
              subtitle: Text(
                'You will appear as "A believer".',
                style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerAction extends StatelessWidget {
  const _ComposerAction({
    required this.canPublish,
    required this.busy,
    required this.length,
    required this.onPublish,
  });

  final bool canPublish;
  final bool busy;
  final int length;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy,
        border: Border(
          top: BorderSide(color: AppColors.navyLine.withValues(alpha: 0.8)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Insets.page,
            Insets.md,
            Insets.page,
            Insets.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (length > 0 && length < 40)
                Padding(
                  padding: const EdgeInsets.only(bottom: Insets.sm),
                  child: Text(
                    '${40 - length} more characters needed',
                    style: AppType.bodySm.copyWith(color: AppColors.amber),
                  ),
                ),
              PrimaryButton(
                label: 'Share story',
                icon: Icons.send_rounded,
                busy: busy,
                onPressed: canPublish ? onPublish : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
