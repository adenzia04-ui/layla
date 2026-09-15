import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Labelled field matching the auth sheet in the reference: a small caption
/// above, a rounded field below.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.obscure = false,
    this.validator,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.prefixIcon,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final IconData? prefixIcon;
  final bool enabled;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.label,
          style: AppType.bodySm.copyWith(
            color: scheme.onSurface.withValues(alpha: 0.72),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: _hidden,
          validator: widget.validator,
          enabled: widget.enabled,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          onFieldSubmitted: widget.onSubmitted,
          style: AppType.body.copyWith(color: scheme.onSurface),
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, size: 19),
            suffixIcon: widget.obscure
                ? IconButton(
                    onPressed: () => setState(() => _hidden = !_hidden),
                    iconSize: 20,
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                  )
                : null,
          ),
        ),
        const SizedBox(height: Insets.md),
      ],
    );
  }
}
