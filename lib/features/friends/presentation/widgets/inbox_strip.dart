import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../application/friends_controller.dart';
import '../../domain/inbox_item.dart';
import 'inbox_sheets.dart';

/// What friends have sent you, at the top of the Friends screen.
///
/// Nothing at all when the inbox is empty — not a header saying so. The strip
/// is news, and a permanent slot for news that is usually absent would only
/// teach the eye to skip it.
class InboxStrip extends ConsumerWidget {
  const InboxStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<InboxItem> items =
        ref.watch(inboxProvider).valueOrNull ?? const <InboxItem>[];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.xl),
      child: NightCard(
        borderColor: AppColors.gold.withValues(alpha: 0.45),
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm,
          vertical: Insets.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < items.length; i++) ...<Widget>[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: Insets.sm,
                  endIndent: Insets.sm,
                  color: AppColors.navyLine.withValues(alpha: 0.7),
                ),
              InboxRow(
                item: items[i],
                onTap: () => openInboxItem(context, ref, items[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One thing a friend sent: its glyph, its sentence, and the way in.
class InboxRow extends StatelessWidget {
  const InboxRow({super.key, required this.item, required this.onTap});

  final InboxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Insets.sm,
          vertical: Insets.md,
        ),
        child: Row(
          children: <Widget>[
            Icon(inboxIcon(item), size: 18, color: AppColors.gold),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Text(
                inboxSentence(item),
                style: AppType.titleSm.copyWith(color: AppColors.cream),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Insets.sm),
            if (item.type == InboxType.circle)
              Text(
                'Join',
                style: AppType.titleSm.copyWith(color: AppColors.gold),
              )
            else
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
