import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'app_button.dart';
import 'ornament_backdrop.dart';

/// Slowly breathing khatim — Noor's loading indicator.
class NoorLoader extends StatefulWidget {
  const NoorLoader({super.key, this.size = 40, this.message});

  final double size;
  final String? message;

  @override
  State<NoorLoader> createState() => _NoorLoaderState();
}

class _NoorLoaderState extends State<NoorLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedBuilder(
          animation: _c,
          builder: (BuildContext context, Widget? child) {
            final double pulse =
                0.75 + 0.25 * (0.5 + 0.5 * -Curves.easeInOut.transform(
                    (_c.value * 2 % 1.0),));
            return Transform.rotate(
              angle: _c.value * 6.2831853,
              child: Opacity(
                opacity: pulse,
                child: KhatimMark(size: widget.size),
              ),
            );
          },
        ),
        if (widget.message != null) ...<Widget>[
          const SizedBox(height: Insets.lg),
          Text(
            widget.message!,
            textAlign: TextAlign.center,
            style: AppType.bodySm.copyWith(color: AppColors.mist),
          ),
        ],
      ],
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) =>
      Center(child: NoorLoader(message: message));
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.body,
    this.icon = Icons.nights_stay_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? body;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 44, color: AppColors.goldDim),
            const SizedBox(height: Insets.lg),
            Text(title, style: AppType.displaySm, textAlign: TextAlign.center),
            if (body != null) ...<Widget>[
              const SizedBox(height: Insets.sm),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: AppColors.mist),
              ),
            ],
            if (actionLabel != null) ...<Widget>[
              const SizedBox(height: Insets.xl),
              PrimaryButton(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyView(
        icon: Icons.error_outline_rounded,
        title: 'Something went wrong',
        body: message,
        actionLabel: onRetry == null ? null : 'Try again',
        onAction: onRetry,
      );
}
