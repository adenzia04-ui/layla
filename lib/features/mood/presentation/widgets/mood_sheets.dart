import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../application/mood_store.dart';
import '../../domain/mood_comfort.dart';
import '../../domain/mood_extras.dart';

/// A story from the Qur'an, read in a sheet.
Future<void> showStorySheet(
  BuildContext context, {
  required QuranStory story,
  required Color tone,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.navy,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (BuildContext context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.94,
      builder: (BuildContext context, ScrollController controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          Insets.xl,
          Insets.lg,
          Insets.xl,
          Insets.xxl,
        ),
        children: <Widget>[
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.navyLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: Insets.lg),
          Text('FROM THE QUR\'AN', style: AppType.label.copyWith(color: tone)),
          const SizedBox(height: Insets.sm),
          Text(story.title, style: AppType.displaySm),
          const SizedBox(height: Insets.lg),
          Text(
            story.body,
            style: AppType.body.copyWith(
              color: AppColors.cream,
              fontSize: 16,
              height: 1.7,
            ),
          ),
          const SizedBox(height: Insets.lg),
          Text(
            story.reference,
            style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
          ),
        ],
      ),
    ),
  );
}

/// A hadith, opened: the text, then what it means for this feeling.
Future<void> showHadithSheet(
  BuildContext context, {
  required HadithStory hadith,
  required Color tone,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.navy,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (BuildContext context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.94,
      builder: (BuildContext context, ScrollController controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          Insets.xl,
          Insets.lg,
          Insets.xl,
          Insets.xxl,
        ),
        children: <Widget>[
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.navyLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: Insets.lg),
          Text('FROM THE HADITH', style: AppType.label.copyWith(color: tone)),
          const SizedBox(height: Insets.sm),
          Text(hadith.title, style: AppType.displaySm),
          const SizedBox(height: Insets.lg),
          Text(
            hadith.body,
            style: AppType.body.copyWith(
              color: AppColors.cream,
              fontSize: 16,
              height: 1.7,
            ),
          ),
          const SizedBox(height: Insets.md),
          Text(
            hadith.reference,
            style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
          ),
          const SizedBox(height: Insets.xl),
          Container(
            padding: const EdgeInsets.all(Insets.lg),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: tone.withValues(alpha: 0.35)),
            ),
            child: Text(
              hadith.lesson,
              style: AppType.body.copyWith(color: AppColors.cream, height: 1.6),
            ),
          ),
        ],
      ),
    ),
  );
}

/// "How do you feel now?" — one line, kept on the phone.
Future<void> showJournalSheet(
  BuildContext context, {
  required Mood mood,
  Comfort? comfort,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.navy,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg)),
    ),
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _JournalForm(mood: mood, comfort: comfort),
    ),
  );
}

class _JournalForm extends ConsumerStatefulWidget {
  const _JournalForm({required this.mood, this.comfort});

  final Mood mood;
  final Comfort? comfort;

  @override
  ConsumerState<_JournalForm> createState() => _JournalFormState();
}

class _JournalFormState extends ConsumerState<_JournalForm> {
  final TextEditingController _text = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String note = _text.text.trim();
    if (note.isEmpty || _saving) return;
    setState(() => _saving = true);
    await ref
        .read(moodJournalProvider.notifier)
        .add(
          JournalEntry(
            at: DateTime.now(),
            mood: widget.mood,
            note: note,
            comfortId: widget.comfort?.id,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final Color tone = widget.mood.tone;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Insets.xl,
        Insets.lg,
        Insets.xl,
        Insets.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('AFTERWARDS', style: AppType.label.copyWith(color: tone)),
          const SizedBox(height: Insets.sm),
          Text('How do you feel now?', style: AppType.displaySm),
          const SizedBox(height: Insets.xs),
          Text(
            'A line for yourself. It stays on this phone and goes nowhere.',
            style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
          ),
          const SizedBox(height: Insets.lg),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            style: AppType.body.copyWith(color: AppColors.cream, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Lighter. Still heavy. A little less alone…',
              hintStyle: AppType.body.copyWith(color: AppColors.mistFaint),
              filled: true,
              fillColor: AppColors.navyElevated,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Radii.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: Insets.lg),
          PrimaryButton(label: 'Keep this', busy: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
