import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../application/friends_controller.dart';
import '../../application/invite.dart';
import '../../domain/friend.dart';

/// The one sentence each way adding a friend can fail.
///
/// Plain sentences, not codes: the person typing a code does not know what a
/// "friend_codes document" is, and should not have to.
String friendAddSentence(FriendAddError error) => switch (error) {
  FriendAddError.invalidCode => 'A code has six letters and numbers.',
  FriendAddError.notFound => 'That code does not belong to anyone.',
  FriendAddError.yourself => 'That is your own code.',
  FriendAddError.already => 'You are already friends.',
  // The three that are about the account or the other person, not the code,
  // in the words the domain already chose for them.
  FriendAddError.guest ||
  FriendAddError.notSignedIn ||
  FriendAddError.refused => error.message,
};

/// Keeps the field looking like a code while it is typed.
///
/// Everything outside the code alphabet is dropped as it arrives — lowercase
/// is lifted, a pasted "abc-234" or "ABC 234" lands as ABC-234 — and the
/// hyphen is put in after the third character so what the person sees is
/// exactly what their friend read out.
class FriendCodeFormatter extends TextInputFormatter {
  const FriendCodeFormatter();

  /// "ABC-2" from "ABC2": the display form, for however much has been typed.
  static String shape(String raw) {
    final String code = FriendCode.normalize(raw);
    if (code.length <= 3) return code;
    return '${code.substring(0, 3)}-${code.substring(3)}';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String shown = shape(newValue.text);
    // The caret sits at the end. A code is typed forwards or pasted whole;
    // nobody edits the middle of one, and keeping the caret honest through
    // an inserted hyphen is not worth the arithmetic.
    return TextEditingValue(
      text: shown,
      selection: TextSelection.collapsed(offset: shown.length),
    );
  }
}

/// "Add a friend": the code field and the button under it.
///
/// The same six characters open a circle too. A code nobody owns as a friend
/// code is tried as a circle's before the person is told it belongs to no
/// one — they typed what they were given, and should not have to know which
/// kind it was.
class AddFriendField extends ConsumerStatefulWidget {
  const AddFriendField({super.key});

  @override
  ConsumerState<AddFriendField> createState() => _AddFriendFieldState();
}

class _AddFriendFieldState extends ConsumerState<AddFriendField> {
  final TextEditingController _code = TextEditingController();

  /// The sentence under the field, when there is one.
  String? _error;

  /// A circle join on its way — the friend add has its own busy state.
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    // A code that arrived through a link is already in the field when the
    // screen opens; the person only has to say yes.
    final String? pending = ref.read(pendingInviteProvider);
    if (pending != null) _code.text = FriendCodeFormatter.shape(pending);
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String code = FriendCode.normalize(_code.text);
    if (!FriendCode.isValid(code)) {
      setState(() => _error = friendAddSentence(FriendAddError.invalidCode));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    Friend? friend;
    try {
      friend = await ref.read(friendsActionsProvider.notifier).add(code);
    } on FriendAddException catch (error) {
      if (mounted) await _failed(code, error.error);
      return;
    } on Object catch (error) {
      if (mounted) context.showError(error);
      return;
    }
    if (!mounted) return;

    if (friend == null) {
      // The controller kept the failure in its state rather than throwing it.
      final Object? error = ref.read(friendsActionsProvider).error;
      if (error is FriendAddException) {
        await _failed(code, error.error);
      } else {
        context.showError(
          error ?? 'That could not be saved. Try again in a moment.',
        );
      }
      return;
    }

    _code.clear();
    ref.read(pendingInviteProvider.notifier).state = null;
    context.showSuccess('You and ${friend.name} are now friends.');
  }

  /// The add did not go through for a reason the person can act on. A code
  /// that is nobody's friend code gets one more try, as a circle's.
  Future<void> _failed(String code, FriendAddError error) async {
    if (error == FriendAddError.notFound) {
      await _joinCircle(code);
      return;
    }
    setState(() => _error = friendAddSentence(error));
  }

  Future<void> _joinCircle(String code) async {
    setState(() => _joining = true);
    // The controller keeps a refusal in its state rather than throwing it,
    // the same way the friend add does.
    final Circle? circle = await ref
        .read(circleActionsProvider.notifier)
        .join(code);
    if (!mounted) return;
    setState(() => _joining = false);
    if (circle != null) {
      _code.clear();
      context.showSuccess('You are in ${circle.name}.');
      unawaited(context.push(Routes.circle(circle.id)));
      return;
    }

    final Object? error = ref.read(circleActionsProvider).error;
    if (error == null) {
      // Joined, but the circle could not be read back yet; the list will
      // show it when it can.
      _code.clear();
      context.showSuccess('You are in. The circle appears under Together.');
      return;
    }
    if (error is! CircleJoinException) {
      context.showError(error);
      return;
    }
    // No circle has it either: the friend-code sentence still holds, and it
    // is the sentence the person expects under a field labelled with both.
    // The other refusals — already in it, full — are said in their own words.
    setState(
      () => _error = switch (error.error) {
        CircleJoinError.notFound || CircleJoinError.invalidCode =>
          friendAddSentence(FriendAddError.notFound),
        _ => error.message,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // A link opened while this screen is already up lands here too.
    ref.listen<String?>(pendingInviteProvider, (
      String? previous,
      String? next,
    ) {
      if (next == null || next == previous) return;
      setState(() {
        _code.text = FriendCodeFormatter.shape(next);
        _error = null;
      });
    });
    final String? pending = ref.watch(pendingInviteProvider);
    final bool fromLink =
        pending != null &&
        FriendCode.normalize(_code.text) == FriendCode.normalize(pending);
    final bool busy = ref.watch(friendsActionsProvider).isLoading || _joining;
    final TextStyle letters = AppType.numeral.copyWith(
      fontSize: 18,
      letterSpacing: 3,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // The caption-then-field shape of AppTextField, drawn here because
        // that widget has no way to take a formatter or a spaced-out style.
        Text(
          'Friend or circle code',
          style: AppType.bodySm.copyWith(
            color: AppColors.cream.withValues(alpha: 0.72),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _code,
          enabled: !busy,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          inputFormatters: const <TextInputFormatter>[FriendCodeFormatter()],
          onSubmitted: (_) => _submit(),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          style: letters.copyWith(color: AppColors.cream),
          decoration: InputDecoration(
            hintText: 'ABC-234',
            hintStyle: letters.copyWith(
              color: AppColors.cream.withValues(alpha: 0.3),
            ),
            prefixIcon: const Icon(Icons.person_add_alt_1_outlined, size: 19),
            errorText: _error,
            errorStyle: AppType.bodySm.copyWith(color: AppColors.rose),
          ),
        ),
        if (fromLink && _error == null) ...<Widget>[
          const SizedBox(height: Insets.sm),
          Row(
            children: <Widget>[
              const Icon(
                Icons.link_rounded,
                size: 14,
                color: AppColors.goldDim,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'This code came from a link a friend shared. Add them?',
                  style: AppType.bodySm.copyWith(color: AppColors.goldDim),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: Insets.md),
        PrimaryButton(label: 'Add friend', busy: busy, onPressed: _submit),
      ],
    );
  }
}
