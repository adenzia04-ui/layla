import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../mood/application/mood_store.dart';
import '../../../mood/domain/mood_comfort.dart';
import '../../../mood/presentation/widgets/comfort_face.dart';
import '../../application/friends_controller.dart';
import '../../domain/friend.dart';

/// "Send a verse": your saved cards first, then any card by the feeling it
/// was written for. The card goes as it is — no message with it.
Future<void> showVersePicker(BuildContext context, Friend friend) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.navy,
    shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
    builder: (BuildContext context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.94,
      builder: (BuildContext context, ScrollController controller) =>
          _VersePicker(friend: friend, controller: controller),
    ),
  );
}

class _VersePicker extends ConsumerStatefulWidget {
  const _VersePicker({required this.friend, required this.controller});

  final Friend friend;
  final ScrollController controller;

  @override
  ConsumerState<_VersePicker> createState() => _VersePickerState();
}

class _VersePickerState extends ConsumerState<_VersePicker> {
  /// The feeling whose cards are open below the chips, if any.
  Mood? _mood;

  /// The card on its way, so a second tap cannot send it twice.
  String? _sending;

  /// The "By feeling" line, so a picked feeling can bring its cards up.
  final GlobalKey _feelingKey = GlobalKey();

  /// Opens (or closes) [m]'s cards, and scrolls so they can be seen.
  ///
  /// On a small phone the twelve chips fill the sheet by themselves; a tap
  /// that only changed something below the fold would look like nothing
  /// happened. Putting the "By feeling" line at the top leaves the chips in
  /// reach and the first card, Send in its corner, under them.
  void _pick(Mood m) {
    final Mood? next = m == _mood ? null : m;
    setState(() => _mood = next);
    if (next == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? feeling = _feelingKey.currentContext;
      if (!mounted || feeling == null) return;
      Scrollable.ensureVisible(
        feeling,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send(Comfort comfort) async {
    if (_sending != null) return;
    setState(() => _sending = comfort.id);
    await ref
        .read(friendsActionsProvider.notifier)
        .sendVerse(widget.friend.uid, comfort.id);
    if (!mounted) return;
    // The controller keeps a failure in its state rather than throwing it.
    final Object? error = ref.read(friendsActionsProvider).error;
    if (error != null) {
      setState(() => _sending = null);
      context.showError(error);
      return;
    }
    Navigator.of(context).pop();
    context.showSuccess(
      'Sent. ${widget.friend.name} sees it when they next open Layla Pro.',
    );
  }

  @override
  Widget build(BuildContext context) {
    // Most recently kept first, the same order as the Saved screen.
    final List<Comfort> saved = <Comfort>[
      for (final String id
          in ref.watch(savedComfortsProvider).toList().reversed)
        if (MoodComfort.byId(id) case final Comfort c) c,
    ];
    final Mood? mood = _mood;

    return ListView(
      controller: widget.controller,
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
        Text(
          'SEND A VERSE',
          style: AppType.label.copyWith(color: AppColors.gold),
        ),
        const SizedBox(height: Insets.sm),
        Text(
          'For ${widget.friend.name}',
          style: AppType.displaySm,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: Insets.xs),
        Text(
          'Only the card goes, with your name on it. They see it when they '
          'next open Layla Pro.',
          style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
        ),
        if (saved.isNotEmpty) ...<Widget>[
          const SizedBox(height: Insets.xl),
          const _Eyebrow('Your saved cards'),
          for (final Comfort c in saved) _Card(comfort: c, onSend: _send),
        ],
        const SizedBox(height: Insets.xl),
        _Eyebrow('By feeling', key: _feelingKey),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.sm,
          children: <Widget>[
            for (final Mood m in Mood.values)
              AppChip(
                label: m.label,
                icon: m.icon,
                selected: m == mood,
                onTap: () => _pick(m),
              ),
          ],
        ),
        if (mood != null) ...<Widget>[
          const SizedBox(height: Insets.lg),
          for (final Comfort c in MoodComfort.forMood(mood))
            _Card(comfort: c, tone: mood.tone, onSend: _send),
        ] else ...<Widget>[
          const SizedBox(height: Insets.md),
          Text(
            saved.isEmpty
                ? 'Pick a feeling to see its cards.'
                : 'Or pick a feeling to see its cards.',
            style: AppType.bodySm.copyWith(color: AppColors.mistFaint),
          ),
        ],
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Insets.md),
    child: Text(
      text.toUpperCase(),
      style: AppType.label.copyWith(color: AppColors.goldDim),
    ),
  );
}

/// One card, as it looks in Mood, with Send in its corner.
class _Card extends StatelessWidget {
  const _Card({required this.comfort, required this.onSend, this.tone});

  final Comfort comfort;
  final Color? tone;
  final ValueChanged<Comfort> onSend;

  @override
  Widget build(BuildContext context) {
    final List<Mood> moods = MoodComfort.moodsFor(comfort);
    final Color color =
        tone ?? (moods.isEmpty ? AppColors.gold : moods.first.tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.md),
      child: ComfortFace(
        comfort: comfort,
        tone: color,
        minHeight: 0,
        trailing: _SendChip(onPressed: () => onSend(comfort)),
      ),
    );
  }
}

/// The small gold pill in a card's corner.
class _SendChip extends StatelessWidget {
  const _SendChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.midnight,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: Insets.md),
        textStyle: AppType.titleSm,
        shape: const StadiumBorder(),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.send_rounded, size: 15),
          SizedBox(width: 6),
          Text('Send'),
        ],
      ),
    );
  }
}
