import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'ornament_backdrop.dart';

/// Every night-themed screen in Noor is built on this: the navy gradient
/// ground, the gold ornament band, and a transparent app bar.
class NightScaffold extends StatelessWidget {
  const NightScaffold({
    super.key,
    required this.child,
    this.title,
    this.leading,
    this.actions,
    this.showOrnaments = true,
    this.ornamentHeight,
    this.padding = Insets.pageH,
    this.scrollable = false,
    this.bottom,
    this.floatingActionButton,
  });

  final Widget child;
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showOrnaments;
  final double? ornamentHeight;
  final EdgeInsets padding;

  /// Wraps [child] in a scroll view with bottom-safe padding.
  final bool scrollable;
  final Widget? bottom;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final Widget body = Padding(padding: padding, child: child);

    // The back button, a title and any actions sit inside the page, at the
    // page's own margin, the way the Mood screen lays out its row. They used
    // to go through an AppBar, whose 56-point leading slot put the button
    // further left and lower than every screen that drew its own.
    final Widget? header = title == null && leading == null && actions == null
        ? null
        : Padding(
            padding: EdgeInsets.only(
              left: padding.left,
              right: padding.right,
              top: Insets.sm,
            ),
            child: Row(
              children: <Widget>[
                if (leading != null) leading!,
                if (title != null) ...<Widget>[
                  if (leading != null) const SizedBox(width: Insets.md),
                  Expanded(child: Text(title!, style: AppType.displaySm)),
                ] else
                  const Spacer(),
                ...?actions,
              ],
            ),
          );
    final Widget content = header == null
        ? body
        : scrollable
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[header, body],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              header,
              Expanded(child: body),
            ],
          );

    return Scaffold(
      backgroundColor: AppColors.midnight,
      // Any FAB gets the same clearance as pinned content, so a future screen
      // does not quietly hide its own button behind the floating tab bar.
      floatingActionButton: floatingActionButton == null
          ? null
          : Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              child: floatingActionButton,
            ),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.nightSky),
            ),
          ),
          if (showOrnaments)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: OrnamentBackdrop(height: ornamentHeight ?? 300),
            ),
          SafeArea(
            bottom: false,
            child: scrollable
                ? SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom + Insets.xxl,
                    ),
                    child: content,
                  )
                // Non-scrolling screens need the same clearance. Tasbih pushes
                // its Reset and Count buttons down with a `Spacer`, and with no
                // bottom padding they ended up underneath the floating tab bar
                // — visible through the glass, but not tappable.
                //
                // The inset comes from MediaQuery rather than a constant: the
                // shell adds the bar's height to it, so screens pushed on top
                // of the shell, which have no bar, correctly get only the
                // device's own inset.
                : Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.paddingOf(context).bottom,
                    ),
                    child: content,
                  ),
          ),
        ],
      ),
      bottomNavigationBar: bottom,
    );
  }
}

/// A translucent card on the night ground — the default container for content.
class NightCard extends StatelessWidget {
  const NightCard({
    super.key,
    required this.child,
    this.padding = Insets.card,
    this.onTap,
    this.gradient,
    this.borderColor,
    this.radius = Radii.lg,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null
            ? AppColors.navyElevated.withValues(alpha: 0.55)
            : null,
        borderRadius: br,
        border: Border.all(
          color: borderColor ?? AppColors.navyLine.withValues(alpha: 0.8),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: br,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
