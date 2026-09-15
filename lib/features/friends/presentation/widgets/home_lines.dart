import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../application/friends_controller.dart';
import '../../domain/inbox_item.dart';
import 'inbox_sheets.dart';

/// The Eid that has already had its greeting sent from this phone, this
/// session, so the line goes the moment it is tapped rather than when the
/// write comes back.
final StateProvider<int?> _eidSentNowProvider = StateProvider<int?>(
  (Ref ref) => null,
);

/// One tap on Eid morning: "Eid Mubarak from you" to every friend, once.
///
/// A line, not a card of its own — Home is already full on a morning when
/// nobody is looking at their phone for long. It goes as soon as it is sent,
/// and does not come back for that Eid.
class EidGreetingLine extends ConsumerWidget {
  const EidGreetingLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int? eid = ref.watch(eidTodayProvider);
    if (eid == null) return const SizedBox.shrink();
    if (ref.watch(eidSentProvider) || ref.watch(_eidSentNowProvider) == eid) {
      return const SizedBox.shrink();
    }
    final bool busy = ref.watch(friendsActionsProvider).isLoading;

    Future<void> send() async {
      await ref.read(friendsActionsProvider.notifier).sendEid();
      if (!context.mounted) return;
      // The controller keeps a failure in its state rather than throwing it.
      final Object? error = ref.read(friendsActionsProvider).error;
      if (error != null) {
        context.showError(error);
        return;
      }
      ref.read(_eidSentNowProvider.notifier).state = eid;
      context.showSuccess('Sent. Eid Mubarak.');
    }

    return _HomeLine(
      icon: Icons.nightlight_round,
      iconColor: AppColors.goldSoft,
      text: 'Send Eid greetings to your friends',
      detail: eid == 1 ? 'Eid al-Fitr · one tap' : 'Eid al-Adha · one tap',
      onTap: busy ? null : send,
    );
  }
}

/// What friends have sent, as one line: "Saad sent you a verse".
///
/// Tapping opens the first of them; the rest wait their turn, and the line
/// says how many are waiting.
class InboxLine extends ConsumerWidget {
  const InboxLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<InboxItem> items =
        ref.watch(inboxProvider).valueOrNull ?? const <InboxItem>[];
    if (items.isEmpty) return const SizedBox.shrink();
    final InboxItem first = items.first;
    final int more = items.length - 1;

    return _HomeLine(
      icon: inboxIcon(first),
      iconColor: AppColors.gold,
      text: inboxSentence(first),
      detail: more == 0
          ? null
          : (more == 1 ? '1 more waiting' : '$more more waiting'),
      onTap: () => openInboxItem(context, ref, first),
    );
  }
}

/// A single tappable line on the night ground, the height of one thought.
class _HomeLine extends StatelessWidget {
  const _HomeLine({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.onTap,
    this.detail,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Insets.md),
      child: NightCard(
        onTap: onTap,
        borderColor: AppColors.gold.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.lg,
          vertical: Insets.md + 2,
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    text,
                    style: AppType.titleSm.copyWith(color: AppColors.cream),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (detail != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      detail!,
                      style: AppType.bodySm.copyWith(
                        color: AppColors.mistFaint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.mistFaint,
            ),
          ],
        ),
      ),
    );
  }
}
