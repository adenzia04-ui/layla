import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/routing/routes.dart';
import '../core/widgets/liquid_glass.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../core/utils/formatters.dart';
import '../features/prayer_lock/application/prayer_lock_controller.dart';
import '../features/prayer_lock/application/prayer_lock_sync.dart';
import '../features/widgets/application/widget_publisher.dart';
import '../features/prayer_lock/domain/prayer_session.dart';
import '../features/prayer_times/application/prayer_times_controller.dart';

/// The five-tab frame. Each branch keeps its own navigator, so leaving Qibla
/// for Tasbih and coming back does not reset the screen.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<({IconData icon, IconData active, String label})> _tabs =
      <({IconData icon, IconData active, String label})>[
    (
      icon: Icons.home_outlined,
      active: Icons.home_rounded,
      label: 'Home',
    ),
    (
      icon: Icons.bedtime_outlined,
      active: Icons.bedtime_rounded,
      label: 'Tahajjud',
    ),
    (
      icon: Icons.explore_outlined,
      active: Icons.explore_rounded,
      label: 'Qibla',
    ),
    (
      icon: Icons.radio_button_unchecked,
      active: Icons.radio_button_checked,
      label: 'Tasbih + Dua',
    ),
    (
      icon: Icons.person_outline_rounded,
      active: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the OS-side prayer windows in step with the computed times. On
    // iOS this is what lets the Screen Time shield rise while Noor is closed.
    // Notification scheduling belongs here, not on the Home tab. It used to
    // be watched from `home_screen`, so reminders were only ever (re)scheduled
    // while Home happened to be built — open the app on Profile, or reinstall
    // it (which wipes every pending notification), and the rest of the day's
    // adhans were simply never queued.
    ref.watch(prayerNotificationSyncProvider);
    ref.watch(prayerLockSyncProvider);
    ref.watch(prayerLockReleaseProvider);

    // Keeps the home-screen widgets and the Live Activity in step.
    ref.watch(widgetSyncProvider);

    final PrayerSession? session = ref.watch(activeSessionProvider);

    return Scaffold(
      backgroundColor: AppColors.midnight,
      // The bar is translucent, so the content has to run underneath it —
      // otherwise the blur has nothing to work on and the glass reads as a
      // flat panel. Screens add their own bottom padding for the overlap.
      extendBody: true,
      // Hand the bar's own height down as bottom padding. Without it every
      // screen thinks it owns the full viewport and the last thing on each
      // one ends up parked under the glass, unreachable by scrolling.
      body: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: MediaQuery.of(context).padding.copyWith(
                bottom:
                    MediaQuery.of(context).padding.bottom + kBottomBarHeight,
              ),
        ),
        child: navigationShell,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (session != null) _FocusBanner(session: session),
          _BottomBar(
            index: navigationShell.currentIndex,
            onTap: (int index) => navigationShell.goBranch(
              index,
              // Tapping the current tab again pops it back to its root.
              initialLocation: index == navigationShell.currentIndex,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sits above the navigation bar whenever a prayer window is open and
/// unconfirmed, so the user always has one tap back into focus.
class _FocusBanner extends ConsumerWidget {
  const _FocusBanner({required this.session});

  final PrayerSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = ref.watch(clockProvider).value ?? DateTime.now();
    final bool needsPhoto = session.awaitingProof;

    return Material(
      color: needsPhoto
          ? AppColors.amber.withValues(alpha: 0.18)
          : session.prayer.palette.start,
      child: InkWell(
        onTap: () => context.push(Routes.focus(session.prayer.key)),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg,
            vertical: Insets.md,
          ),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: needsPhoto ? AppColors.amber : AppColors.gold,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                needsPhoto ? Icons.photo_camera_rounded : session.prayer.icon,
                size: 19,
                color: needsPhoto ? AppColors.amber : AppColors.cream,
              ),
              const SizedBox(width: Insets.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      needsPhoto
                          ? '${session.prayer.label} needs a prayer mat photo'
                          : '${session.prayer.label} window is open',
                      style: AppType.titleSm.copyWith(color: AppColors.cream),
                    ),
                    Text(
                      // Sessions no longer expire, so past the window `mmss`
                      // would sit at 00:00 and read as a frozen clock.
                      session.isOverdueAt(now)
                          ? 'Apps stay paused until you confirm'
                          : needsPhoto
                              ? 'Not confirmed yet · '
                                  '${Fmt.mmss(session.remaining(now))} left'
                              : '${Fmt.mmss(session.remaining(now))} left to confirm',
                      style: AppType.bodySm.copyWith(
                        fontSize: 11,
                        color: AppColors.mist,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mistFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Height of the floating bar plus the gap beneath it. Screens add this to
/// their scroll padding so nothing ends up parked under the glass.
const double kBottomBarHeight = 78;

const double _barHeight = 62;
const double _barInset = 14;

class _BottomBar extends StatefulWidget {
  const _BottomBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  /// Where the finger has the lens, as a fractional tab index. Null when
  /// nobody is dragging, in which case the lens animates to the selected tab.
  double? _drag;

  /// True from the moment a finger lands on the bar until it lifts. The lens
  /// swells while held, the way a physical control gives under pressure.
  bool _pressed = false;

  int get index => widget.index;
  ValueChanged<int> get onTap => widget.onTap;

  void _moveTo(double x, double width) {
    final int count = AppShell._tabs.length;
    final double slot = width / count;
    setState(() {
      // Clamped to the strip so the lens cannot be dragged off the ends.
      _drag = (x / slot - 0.5).clamp(0.0, count - 1.0);
    });
  }

  void _release() {
    final double? at = _drag;
    setState(() => _drag = null);
    if (at == null) return;
    final int landed = at.round();
    if (landed != index) onTap(landed);
  }

  @override
  Widget build(BuildContext context) {
    // A floating pill rather than an edge-to-edge strip, with a glass lens
    // that slides to whichever tab is selected — the iOS 26 treatment. The
    // lens is what does the work: a bright rim, a faint chromatic fringe and
    // a lift shadow read as a piece of glass sitting on top of the bar.
    final BorderRadius pill = BorderRadius.circular(_barHeight / 2);
    return SafeArea(
      top: false,
      child: Listener(
        // Raw pointer events rather than a gesture: these never enter the
        // arena, so watching for a press cannot steal a tab tap or the drag.
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_barInset, 0, _barInset, 10),
          child: DecoratedBox(
            // Cast shadow, outside the clip. It is what separates the glass from
            // the page behind it; without it the bar reads as a hole rather than
            // as a pane sitting above the interface.
            decoration: BoxDecoration(
              borderRadius: pill,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.30),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: pill,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 34, sigmaY: 34),
                child: Container(
                  height: _barHeight,
                  foregroundDecoration: const ShapeDecoration(
                    // The pane's own surface, painted over the contents: a lit
                    // upper edge falling away to nothing, a whisper of colour
                    // where the curve would split light, and a faint sheen
                    // across the top half.
                    shape: _GlassSurface(),
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        AppColors.navyElevated.withValues(alpha: 0.58),
                        AppColors.navy.withValues(alpha: 0.72),
                      ],
                    ),
                    borderRadius: pill,
                  ),
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      final int count = AppShell._tabs.length;
                      final double slot = c.maxWidth / count;
                      return GestureDetector(
                        // Horizontal only, so a tap still reaches the tabs and a
                        // vertical drag still belongs to the page behind.
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragStart: (DragStartDetails d) =>
                            _moveTo(d.localPosition.dx, c.maxWidth),
                        onHorizontalDragUpdate: (DragUpdateDetails d) =>
                            _moveTo(d.localPosition.dx, c.maxWidth),
                        onHorizontalDragEnd: (DragEndDetails _) => _release(),
                        onHorizontalDragCancel: _release,
                        child: Stack(
                          children: <Widget>[
                            // Real refraction, where the device can do it: a
                            // fragment shader bends and colour-splits the bar behind
                            // the lens, which is the part of Apple's material that
                            // painting cannot fake. Falls back to the painted glass
                            // when the shader is unavailable.
                            TweenAnimationBuilder<double>(
                              tween:
                                  Tween<double>(end: _drag ?? index.toDouble()),
                              // While a finger is on it the lens tracks exactly,
                              // with no easing — anything else feels like lag.
                              // It springs only once released.
                              duration: _drag == null
                                  ? const Duration(milliseconds: 460)
                                  : Duration.zero,
                              curve: Curves.easeOutBack,
                              builder: (
                                BuildContext context,
                                double value,
                                Widget? child,
                              ) {
                                // Distance still to run: 1 at the moment it sets
                                // off, 0 once it has settled.
                                final double travel =
                                    (value - index).abs().clamp(0.0, 1.0);
                                final double stretch = 1 + travel * 0.20;
                                final Rect lens = Rect.fromLTWH(
                                  slot * value + 3,
                                  4,
                                  slot - 6,
                                  _barHeight - 8,
                                );
                                final ui.ImageFilter? refract =
                                    LiquidGlassShader.filter(
                                  area: Size(c.maxWidth, _barHeight),
                                  lens: lens,
                                  radius: (_barHeight - 8) / 2,
                                  strength: 9,
                                );

                                return Positioned.fromRect(
                                  rect: lens,
                                  child: Transform.scale(
                                    scaleX: stretch,
                                    // Conserve a little area, the way a soft body
                                    // would — stretching one axis without giving on
                                    // the other just looks like it grew.
                                    scaleY: 1 - travel * 0.07,
                                    // Swells while a finger is on the bar and
                                    // eases back on release, the way a physical
                                    // control gives under pressure. Animated,
                                    // not switched — a jump reads as a glitch.
                                    child: AnimatedScale(
                                      scale: _pressed ? 1.13 : 1.0,
                                      duration: const Duration(
                                        milliseconds: 170,
                                      ),
                                      curve: Curves.easeOut,
                                      child: refract == null
                                          ? child
                                          : Stack(
                                              children: <Widget>[
                                                Positioned.fill(
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      (_barHeight - 8) / 2,
                                                    ),
                                                    child: BackdropFilter(
                                                      filter: refract,
                                                      child: const SizedBox
                                                          .expand(),
                                                    ),
                                                  ),
                                                ),
                                                Positioned.fill(child: child!),
                                              ],
                                            ),
                                    ),
                                  ),
                                );
                              },
                              child: const _GlassLens(),
                            ),
                            Row(
                              children: <Widget>[
                                for (int i = 0; i < count; i++)
                                  Expanded(
                                    child: _Tab(
                                      data: AppShell._tabs[i],
                                      selected: i == index,
                                      onTap: () => onTap(i),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The surface of a pane of glass, painted over whatever sits inside it.
///
/// Three things, all faint. A rim that is lit along the top curve and fades to
/// nothing by the bottom; a hairline set just inside it, which is what reads as
/// thickness rather than as a drawn outline; and a sheen across the upper half.
///
/// The colour fringes are deliberately near-invisible. Refraction at an edge is
/// a suggestion of colour — the moment cyan and magenta are legible as colours
/// the whole thing stops looking like glass and starts looking like a mistake.
class _GlassSurface extends ShapeBorder {
  const _GlassSurface({
    this.rim = 0.42,
    this.sheen = 0.09,
    this.fringe = 0.10,
  });

  /// Brightness of the lit upper edge, of the sheen below it, and of the
  /// colour split at the curve. The lens carries a little more of each than
  /// the pane, because it is the nearer piece of glass.
  final double rim;
  final double sheen;
  final double fringe;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  ShapeBorder scale(double t) =>
      _GlassSurface(rim: rim * t, sheen: sheen * t, fringe: fringe * t);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()
    ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(rect.height / 2)));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      getInnerPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final Radius r = Radius.circular(rect.height / 2);
    final RRect outer = RRect.fromRectAndRadius(rect.deflate(0.5), r);
    final RRect inner = RRect.fromRectAndRadius(
      rect.deflate(2.2),
      Radius.circular(rect.height / 2 - 1.7),
    );

    // Sheen across the top half, brightest just under the upper edge.
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, r));
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.cream.withValues(alpha: sheen),
            AppColors.cream.withValues(alpha: sheen * 0.22),
            Colors.transparent,
          ],
          stops: const <double>[0, 0.32, 0.62],
        ).createShader(rect),
    );
    canvas.restore();

    // Colour split at the curve, a hair above and below the rim.
    for (final (double dy, Color c) pair in <(double, Color)>[
      (-0.7, const Color(0xFF7FE7FF)),
      (0.7, const Color(0xFFD9A8FF)),
    ]) {
      canvas.drawRRect(
        outer.shift(Offset(0, pair.$1)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..color = pair.$2.withValues(alpha: fringe),
      );
    }

    // The lit rim.
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.cream.withValues(alpha: rim),
            AppColors.cream.withValues(alpha: rim * 0.24),
            AppColors.cream.withValues(alpha: rim * 0.12),
          ],
          stops: const <double>[0, 0.45, 1],
        ).createShader(rect),
    );

    // The hairline inside it — the edge of the pane's thickness.
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            AppColors.cream.withValues(alpha: rim * 0.33),
            Colors.transparent,
          ],
          stops: const <double>[0, 0.55],
        ).createShader(rect),
    );
  }
}

/// The lens over the selected tab.
///
/// Flutter cannot refract without a fragment shader, so the glass is implied
/// rather than simulated: a lit rim brightest at the top-left, a pair of
/// offset colour fringes standing in for chromatic aberration, and a soft
/// drop shadow to lift it off the bar.
class _GlassLens extends StatelessWidget {
  const _GlassLens();

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular((_barHeight - 8) / 2);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.cream.withValues(alpha: 0.30),
            AppColors.cream.withValues(alpha: 0.10),
            AppColors.gold.withValues(alpha: 0.16),
          ],
        ),
        // The original all-round border stays. The lit rim above it is an
        // addition, not a replacement — on its own the gradient fades out by
        // the bottom of the capsule and the shape loses its edge.
        // A definite ring. The lens is a raised piece of glass; without a
        // crisp edge it reads as a smudge of lighter colour on the bar.
        border: Border.all(
          color: AppColors.cream.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // The same surface as the pane, a touch stronger: this is the nearer
      // piece of glass, so its edge catches more of the light.
      child: const DecoratedBox(
        decoration: ShapeDecoration(
          shape: _GlassSurface(rim: 0.85, sheen: 0.22, fringe: 0.16),
        ),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final ({IconData icon, IconData active, String label}) data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The lens marks the selection now, so the old gold underline is gone —
    // two indicators for one state just fight each other.
    final Color color = selected ? AppColors.cream : AppColors.mistFaint;
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(selected ? data.active : data.icon, size: 21, color: color),
          const SizedBox(height: 3),
          Text(
            data.label,
            style: AppType.bodySm.copyWith(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Test-only entry point for the bar, so its glass can be rendered in a golden
/// without standing up the whole router and provider graph.
@visibleForTesting
class BottomBarPreview extends StatelessWidget {
  const BottomBarPreview({super.key, required this.index, this.onTap});

  final int index;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) =>
      _BottomBar(index: index, onTap: onTap ?? (_) {});
}
