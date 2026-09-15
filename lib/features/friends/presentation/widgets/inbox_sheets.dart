import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../circles/application/circles_controller.dart';
import '../../../circles/domain/circle.dart';
import '../../../mood/application/mood_store.dart';
import '../../../mood/domain/mood_comfort.dart';
import '../../../mood/presentation/widgets/comfort_face.dart';
import '../../application/friends_controller.dart';
import '../../domain/inbox_item.dart';

/// The one line an inbox item is announced with, on the Friends strip and on
/// Home: "Saad sent you a verse".
String inboxSentence(InboxItem item) => switch (item.type) {
  InboxType.verse => '${item.fromName} sent you a verse',
  InboxType.eid => 'Eid Mubarak from ${item.fromName}',
  InboxType.circle => '${item.fromName} invited you to a circle',
};

/// The glyph beside that line.
IconData inboxIcon(InboxItem item) => switch (item.type) {
  InboxType.verse => Icons.menu_book_rounded,
  InboxType.eid => Icons.nightlight_round,
  InboxType.circle => Icons.group_add_outlined,
};

/// Opens [item] the way its kind is opened: a verse as the card it names, an
/// Eid greeting as itself, a circle invitation with Join.
///
/// Every sheet's "Done" takes the item out of the inbox; a swipe down leaves
/// it there to be opened again, which is what "read later" is.
Future<void> openInboxItem(
  BuildContext context,
  WidgetRef ref,
  InboxItem item,
) {
  FocusManager.instance.primaryFocus?.unfocus();
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: AppColors.navy,
    builder: (BuildContext context) => switch (item.type) {
      InboxType.verse => _VerseSheet(item: item),
      InboxType.eid => _EidSheet(item: item),
      InboxType.circle => _CircleInviteSheet(item: item),
    },
  );
}

/// Takes [item] out of the inbox, telling the person only if that failed.
Future<void> _dismiss(BuildContext context, WidgetRef ref, String id) async {
  await ref.read(friendsActionsProvider.notifier).dismissInbox(id);
  if (!context.mounted) return;
  // The controller keeps a failure in its state rather than throwing it.
  final Object? error = ref.read(friendsActionsProvider).error;
  if (error != null) context.showError(error);
}

/// A verse or hadith a friend chose for you, as the card it is in Mood.
class _VerseSheet extends ConsumerWidget {
  const _VerseSheet({required this.item});

  final InboxItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Comfort? comfort = MoodComfort.byId(item.comfortId ?? '');
    final Set<String> saved = ref.watch(savedComfortsProvider);
    final bool kept = comfort != null && saved.contains(comfort.id);
    final List<Mood> moods = comfort == null
        ? const <Mood>[]
        : MoodComfort.moodsFor(comfort);
    final Color tone = moods.isEmpty ? AppColors.gold : moods.first.tone;

    return _InboxFrame(
      eyebrow: 'FROM ${item.fromName.toUpperCase()}',
      tone: tone,
      title: '${item.fromName} sent you a verse',
      body: comfort == null
          // A card this build does not know: the friend's app is newer.
          ? Text(
              'This card is not in your copy of Layla Pro yet. Update the app '
              'to read it.',
              style: AppType.body.copyWith(color: AppColors.mist),
            )
          : ComfortFace(comfort: comfort, tone: tone, minHeight: 0),
      actions: <Widget>[
        if (comfort != null)
          GhostButton(
            label: kept ? 'Kept' : 'Keep this card',
            icon: kept ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
            onPressed: kept
                ? null
                : () =>
                      ref.read(savedComfortsProvider.notifier).toggle(comfort),
          ),
        PrimaryButton(
          label: 'Done',
          onPressed: () {
            Navigator.of(context).pop();
            _dismiss(context, ref, item.id);
          },
        ),
      ],
    );
  }
}

/// "Eid Mubarak from Saad."
class _EidSheet extends ConsumerWidget {
  const _EidSheet({required this.item});

  final InboxItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _InboxFrame(
      eyebrow: 'EID',
      tone: AppColors.goldSoft,
      title: 'Eid Mubarak from ${item.fromName}',
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.nightlight_round,
            size: 28,
            color: AppColors.goldSoft,
          ),
          const SizedBox(width: Insets.lg),
          Expanded(
            child: Text(
              'Taqabbal Allahu minna wa minkum — may Allah accept from us and '
              'from you.',
              style: AppType.body.copyWith(color: AppColors.cream),
            ),
          ),
        ],
      ),
      actions: <Widget>[
        PrimaryButton(
          label: 'Ameen',
          onPressed: () {
            Navigator.of(context).pop();
            _dismiss(context, ref, item.id);
          },
        ),
      ],
    );
  }
}

/// A circle you have been asked into, with the one way in.
///
/// The circle's name cannot be shown before joining: its document is readable
/// by members only, and the invitation carries a code, not a name. Saying so
/// is better than a blank where the name should be.
class _CircleInviteSheet extends ConsumerStatefulWidget {
  const _CircleInviteSheet({required this.item});

  final InboxItem item;

  @override
  ConsumerState<_CircleInviteSheet> createState() => _CircleInviteSheetState();
}

class _CircleInviteSheetState extends ConsumerState<_CircleInviteSheet> {
  bool _joining = false;

  Future<void> _join() async {
    final String? code = widget.item.circleCode;
    if (code == null || _joining) return;
    setState(() => _joining = true);
    // The controller keeps a refusal in its state rather than throwing it.
    final Circle? circle = await ref
        .read(circleActionsProvider.notifier)
        .join(code);
    if (!mounted) return;
    final Object? error = ref.read(circleActionsProvider).error;
    if (circle == null && error != null) {
      setState(() => _joining = false);
      // Already in it: the invitation has done its work, so it goes.
      final bool already =
          error is CircleJoinException &&
          error.error == CircleJoinError.already;
      context.showError(error);
      if (!already) return;
    }
    Navigator.of(context).pop();
    await _dismiss(context, ref, widget.item.id);
    if (!mounted) return;
    if (circle != null) {
      context.showSuccess('You are in ${circle.name}.');
      unawaited(context.push(Routes.circle(circle.id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final InboxItem item = widget.item;
    return _InboxFrame(
      eyebrow: 'TOGETHER',
      tone: AppColors.gold,
      title: '${item.fromName} invited you to a circle',
      body: Text(
        'Forty days of one intention, kept together. Everyone in the circle '
        'sees one shared bar and each other\'s days — nothing else.',
        style: AppType.body.copyWith(color: AppColors.mist),
      ),
      actions: <Widget>[
        PrimaryButton(
          label: 'Join',
          icon: Icons.group_add_outlined,
          busy: _joining,
          onPressed: item.circleCode == null ? null : _join,
        ),
        GhostButton(
          label: 'No thanks',
          onPressed: _joining
              ? null
              : () {
                  Navigator.of(context).pop();
                  _dismiss(context, ref, item.id);
                },
        ),
      ],
    );
  }
}

/// The shape the three sheets share: an eyebrow, a title, the thing itself,
/// and the decisions pinned under it.
class _InboxFrame extends StatelessWidget {
  const _InboxFrame({
    required this.eyebrow,
    required this.tone,
    required this.title,
    required this.body,
    required this.actions,
  });

  final String eyebrow;
  final Color tone;
  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Insets.xl,
                Insets.lg,
                Insets.xl,
                0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(eyebrow, style: AppType.label.copyWith(color: tone)),
                  const SizedBox(height: Insets.sm),
                  Text(title, style: AppType.displaySm),
                  const SizedBox(height: Insets.lg),
                  body,
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(Insets.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < actions.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: Insets.sm),
                  actions[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
