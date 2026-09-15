import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/story.dart';

class ReportOutcome {
  const ReportOutcome({required this.reason, required this.note});

  final ReportReason reason;
  final String note;
}

Future<ReportOutcome?> showReportSheet(BuildContext context) {
  return showModalBottomSheet<ReportOutcome>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navy,
    builder: (BuildContext context) => const _ReportSheet(),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet();

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason _reason = ReportReason.harmful;
  final TextEditingController _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Insets.xl,
          Insets.sm,
          Insets.xl,
          MediaQuery.viewInsetsOf(context).bottom + Insets.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Report this story', style: AppType.displaySm),
              const SizedBox(height: Insets.sm),
              Text(
                'Reports are reviewed by a moderator. A story is hidden '
                'automatically once several people report it.',
                style: AppType.bodySm.copyWith(color: AppColors.mist),
              ),
              const SizedBox(height: Insets.lg),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (ReportReason? value) =>
                    setState(() => _reason = value ?? _reason),
                child: Column(
                  children: <Widget>[
                    for (final ReportReason reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: reason,
                        activeColor: AppColors.gold,
                        contentPadding: EdgeInsets.zero,
                        title: Text(reason.label, style: AppType.titleSm),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Insets.md),
              TextField(
                controller: _note,
                maxLines: 3,
                maxLength: 300,
                style: AppType.body.copyWith(color: AppColors.cream),
                decoration: const InputDecoration(
                  hintText: 'Anything else the moderator should know?',
                ),
              ),
              const SizedBox(height: Insets.md),
              PrimaryButton(
                label: 'Send report',
                icon: Icons.flag_rounded,
                onPressed: () => Navigator.of(
                  context,
                ).pop(ReportOutcome(reason: _reason, note: _note.text)),
              ),
              const SizedBox(height: Insets.sm),
              GhostButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
