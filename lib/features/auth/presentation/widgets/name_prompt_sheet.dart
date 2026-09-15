import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/auth_repository.dart';

/// Asks what to call someone, when the provider they signed in with did not
/// say.
///
/// Apple hands back a name on the **first** authorisation for an Apple ID and
/// never again — not on a reinstall, not on a later sign-in, and not on the
/// second attempt after a failed one. Google usually gives a name but is not
/// obliged to. So the app has to be able to ask, or a whole account is stuck
/// being greeted as "friend" with no visible reason why.
///
/// Shown straight after signing in rather than left for Account settings,
/// because somebody who has just been greeted by name-less silence has no
/// reason to go looking for a screen that would fix it.
Future<void> showNamePromptSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: AppColors.navy,
    shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
    builder: (BuildContext context) => _NamePromptSheet(ref: ref),
  );
}

class _NamePromptSheet extends StatefulWidget {
  const _NamePromptSheet({required this.ref});

  final WidgetRef ref;

  @override
  State<_NamePromptSheet> createState() => _NamePromptSheetState();
}

class _NamePromptSheetState extends State<_NamePromptSheet> {
  final TextEditingController _name = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String? error = Validate.name(_name.text);
    if (error != null) {
      context.showError(error);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.ref
          .read(authRepositoryProvider)
          .updateDisplayName(_name.text);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        context.showError(error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lifts the field clear of the keyboard, which covers this sheet
      // entirely on a small phone otherwise.
      padding: EdgeInsets.only(
        left: Insets.xl,
        right: Insets.xl,
        top: Insets.xl,
        bottom: Insets.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('What should I call you?', style: AppType.displaySm),
          const SizedBox(height: Insets.sm),
          Text(
            'Apple did not share your name, so Layla Pro does not know it yet. '
            'It is only used to greet you.',
            style: AppType.bodySm.copyWith(color: AppColors.mist, height: 1.5),
          ),
          const SizedBox(height: Insets.xl),
          AppTextField(
            controller: _name,
            label: 'Your name',
            hint: 'Aden',
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.name],
            validator: Validate.name,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: Insets.lg),
          PrimaryButton(label: 'Save', busy: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
