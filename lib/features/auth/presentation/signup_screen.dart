import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_sheet.dart';

/// Doubles as the guest-upgrade form: when the current user is anonymous the
/// credentials are *linked* instead of creating a second account, so the
/// streak survives.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final AuthController controller =
        ref.read(authControllerProvider.notifier);
    final bool isGuest = ref.read(authRepositoryProvider).isGuest;

    final bool ok = isGuest
        ? await controller.upgradeGuest(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          )
        : await controller.signUp(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          );

    if (!ok || !mounted) return;
    context
      ..showSuccess(
        isGuest
            ? 'Account created — your streak has been kept.'
            : 'Welcome to Layla, ${_name.text.trim().split(' ').first}.',
      )
      ..go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<void> state = ref.watch(authControllerProvider);
    final bool isGuest = ref.watch(authRepositoryProvider).isGuest;

    ref.listen<AsyncValue<void>>(authControllerProvider,
        (AsyncValue<void>? previous, AsyncValue<void> next) {
      if (next.hasError && !next.isLoading) context.showError(next.error!);
    });

    return AuthSheet(
      title: isGuest ? 'Keep your streak' : 'Create your account',
      subtitle: isGuest
          ? 'Add an email and password — every day you have prayed carries over.'
          : 'A few details and your streak starts today.',
      heroFlex: 2,
      sheetFlex: 8,
      onBack: () => context.pop(),
      children: <Widget>[
        Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              AppTextField(
                controller: _name,
                label: 'Name',
                hint: 'What should we call you?',
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.name],
                validator: Validate.name,
              ),
              AppTextField(
                controller: _email,
                label: 'Email address',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.email],
                validator: Validate.email,
              ),
              AppTextField(
                controller: _password,
                label: 'Password',
                hint: 'At least 8 characters',
                obscure: true,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.newPassword],
                validator: Validate.password,
              ),
              AppTextField(
                controller: _confirm,
                label: 'Confirm password',
                hint: 'Type it once more',
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: Validate.confirmPassword(() => _password.text),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: Insets.sm),
              PrimaryButton(
                label: isGuest ? 'Save my account' : 'Create account',
                busy: state.isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: Insets.lg),
              Text(
                'By continuing you agree to keep this a respectful space for '
                'everyone who uses Layla.',
                textAlign: TextAlign.center,
                style: AppType.bodySm.copyWith(color: AppColors.inkMuted),
              ),
              if (!isGuest) ...<Widget>[
                const SizedBox(height: Insets.sm),
                TextButton(
                  onPressed: state.isLoading ? null : () => context.pop(),
                  child: const Text('I already have an account'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
