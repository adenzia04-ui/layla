import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/section_header.dart';
import '../../application/circles_controller.dart';
import '../../domain/circle.dart';
import '../create_circle_sheet.dart';
import 'circle_card.dart';

/// "Together": the circles you are in, and the way to start one.
///
/// Listed in the order they were joined, never by how they are going. A
/// circle is a shared forty days, and the section is a shelf of them rather
/// than a table.
class TogetherSection extends ConsumerWidget {
  const TogetherSection({super.key});

  Future<void> _start(BuildContext context) async {
    final Circle? circle = await showCreateCircleSheet(context);
    if (circle == null || !context.mounted) return;
    unawaited(context.push(Routes.circle(circle.id)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Circle> circles =
        ref.watch(circlesProvider).valueOrNull ?? const <Circle>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader(label: 'Together'),
        if (circles.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Insets.md),
            child: Text(
              'Forty days of Fajr, of all five, or of Tahajjud — kept with a '
              'few people, on one shared bar.',
              style: AppType.body.copyWith(color: AppColors.mist),
            ),
          )
        else
          for (final Circle circle in circles)
            Padding(
              padding: const EdgeInsets.only(bottom: Insets.md),
              child: CircleCard(
                circle: circle,
                onTap: () => context.push(Routes.circle(circle.id)),
              ),
            ),
        GhostButton(
          label: 'Start a circle',
          icon: Icons.add_rounded,
          onPressed: () => _start(context),
        ),
      ],
    );
  }
}
