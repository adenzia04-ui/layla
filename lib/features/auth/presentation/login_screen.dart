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
import 'widgets/auth_sheet.dart';
import 'widgets/social_sign_in.dart';
import 'widgets/guest_notice_sheet.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final bool ok = await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text, password: _password.text);
    if (ok && mounted) context.go(Routes.home);
  }

  Future<void> _guest() async {
    final bool? confirmed = await showGuestNoticeSheet(context);
    if (confirmed != true) return;
    final bool ok = await ref
        .read(authControllerProvider.notifier)
        .continueAsGuest();
    if (ok && mounted) context.go(Routes.home);
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
      title: 'Welcome back',
      subtitle: 'Sign in to continue your streak.',
      heroFlex: 3,
      sheetFlex: 7,
      children: <Widget>[
        Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
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
                hint: 'Your password',
                obscure: true,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.password],
                validator: (String? v) =>
                    (v ?? '').isEmpty ? 'Please enter your password' : null,
                onSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push(Routes.forgotPassword),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: Insets.md),
              PrimaryButton(
                label: 'Log in',
                busy: state.isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: Insets.md),
              GhostButton(
                label: 'Create an account',
                onPressed: state.isLoading
                    ? null
                    : () => context.push(Routes.signup),
              ),
              const SizedBox(height: Insets.xl),
              Row(
                children: <Widget>[
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Insets.md),
                    child: Text(
                      'or',
                      style: AppType.bodySm.copyWith(color: AppColors.inkMuted),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: Insets.lg),
              // The same pair the welcome screen offers. Somebody who came
              // straight here — from a "sign in" link, or by backing out of
              // signup — was previously shown email or nothing, and had to
              // find their way back to the welcome screen to use the account
              // they actually sign in with.
              const SocialSignIn(onLight: true),
              const SizedBox(height: Insets.lg),
              TextButton.icon(
                onPressed: state.isLoading ? null : _guest,
                icon: const Icon(Icons.person_outline_rounded, size: 19),
                label: const Text('Continue without an account'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
