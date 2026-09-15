import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_sheet.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final bool ok = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(_email.text);
    if (ok && mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> state = ref.watch(authControllerProvider);

    ref.listen<AsyncValue<void>>(authControllerProvider, (
      AsyncValue<void>? previous,
      AsyncValue<void> next,
    ) {
      if (next.hasError && !next.isLoading) context.showError(next.error!);
    });

    return AuthSheet(
      title: _sent ? 'Check your email' : 'Reset your password',
      subtitle: _sent
          ? 'If an account exists for ${_email.text.trim()}, a reset link is '
                'on its way. It expires in an hour.'
          : 'Enter your email and we will send you a link to set a new '
                'password.',
      heroFlex: 4,
      sheetFlex: 6,
      onBack: () => context.pop(),
      children: <Widget>[
        if (_sent) ...<Widget>[
          const Icon(
            Icons.mark_email_read_outlined,
            size: 44,
            color: AppColors.emerald,
          ),
          const SizedBox(height: Insets.xl),
          PrimaryButton(label: 'Back to login', onPressed: () => context.pop()),
          const SizedBox(height: Insets.sm),
          TextButton(
            onPressed: state.isLoading ? null : _submit,
            child: const Text('Send it again'),
          ),
        ] else
          Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                AppTextField(
                  controller: _email,
                  label: 'Email address',
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autofillHints: const <String>[AutofillHints.email],
                  validator: Validate.email,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: Insets.sm),
                PrimaryButton(
                  label: 'Send reset link',
                  busy: state.isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: Insets.lg),
                Text(
                  'Guest accounts have no email, so they cannot be reset.',
                  textAlign: TextAlign.center,
                  style: AppType.bodySm.copyWith(color: AppColors.inkMuted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
