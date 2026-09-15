import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/routing/tab_navigators.dart';
import '../core/services/notification_sounds.dart';
import '../core/widgets/liquid_glass.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_typography.dart';
import '../features/circles/application/circles_controller.dart';
import '../features/cycle/application/cycle_controller.dart';
import '../features/friends/application/friends_controller.dart';
import '../features/prayer_lock/application/prayer_lock_sync.dart';
import '../features/widgets/application/widget_publisher.dart';
import '../features/prayer_times/application/prayer_times_controller.dart';
import '../features/streaks/application/late_reminder_sync.dart';
import '../features/prayer_times/application/notification_permission.dart';

/// The three-tab frame. Profile lives on the Home header now, under the
/// settings gear: it is somewhere you go to check on yourself, not somewhere
/// you live, and a tab implied the latter. Each branch keeps its own navigator, so leaving
/// Tahajjud for Tasbih and coming back does not reset the screen.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<({IconData icon, IconData active, String label})> _tabs =
      <({IconData icon, IconData active, String label})>[
        (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'Home'),
        (
          icon: Icons.bedtime_outlined,
          active: Icons.bedtime_rounded,
          label: 'Tahajjud',
        ),
        (
          // A lit lamp with sparks: the inner light this tab tends.
          icon: Icons.tips_and_updates_outlined,
          active: Icons.tips_and_updates_rounded,
          label: 'Soul',
        ),
      ];

  /// Switches to a tab, and taps on the tab you are already on take you back
  /// to the top of it.
  ///
  /// Both halves are needed. `initialLocation: true` clears the pages the
  /// router put on the branch; `popUntil` clears the ones pushed with
  /// `Navigator.push`, which the router never hears about. Duas is three
  /// such screens deep, so before this, tapping Soul from inside it did
  /// nothing whatsoever — the only way back was the system back button, once
  /// per screen.
  void _openTab(int index) {
    final bool again = index == navigationShell.currentIndex;
    if (again) {
      final NavigatorState? nav = index < tabNavigatorKeys.length
          ? tabNavigatorKeys[index].currentState
          : null;
      // `canPop` keeps this from touching a tab already at its root, where
      // popUntil would be a no-op anyway but the check says why.
      if (nav != null && nav.canPop()) {
        nav.popUntil((Route<dynamic> route) => route.isFirst);
      }
    }
    navigationShell.goBranch(index, initialLocation: again);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the OS-side prayer windows in step with the computed times. On
    // iOS this is what lets the Screen Time shield rise while Noor is closed.
    // Notification scheduling belongs here, not on the Home tab. It used to
    // be watched from `home_screen`, so reminders were only ever (re)scheduled
    // while Home happened to be built — open the app on Profile, or reinstall
    // it (which wipes every pending notification), and the rest of the day's
    // adhans were simply never queued.
    // Asks iOS for permission on first run. Nothing else does, so without
    // this a reminder can be scheduled perfectly and still never appear.
    // The chosen reminder sound, applied before anything below schedules.
    ref.watch(reminderSoundProvider);
    ref.watch(notificationPermissionProvider);
    ref.watch(prayerNotificationSyncProvider);
    ref.watch(notificationRefreshProvider);
    // Takes back the "you still have not prayed" call once a prayer is in.
    ref.watch(lateReminderSyncProvider);
    ref.watch(lockPermissionRefreshProvider);
    ref.watch(prayerLockSyncProvider);
    ref.watch(prayerLockReleaseProvider);

    // Records the days of a prayer pause that nobody was open to record. The
    // app cannot rely on being running at midnight, and a covered day left
    // with no record at all is indistinguishable from a day she simply did not
    // pray — which is precisely a broken streak. Idempotent, so this costs one
    // query per app open and nothing after the first.
    ref.watch(cycleCatchUpProvider);
    // Moves the onboarding gender answer onto the account for anybody who
    // onboarded before it was written there, so it stops being device-only.
    ref.watch(genderSyncProvider);

    // Keeps the home-screen widgets and the Live Activity in step.
    ref.watch(widgetSyncProvider);
    // And what friends see of the streak, throttled to a write every few
    // seconds. Quiet for guests, who have no friends list to be seen from.
    ref.watch(progressPublisherProvider);
    // Records a milestone the moment the stats cross one — a hundred days, a
    // thousand prayers — so the publisher above can put it on the scoreboard.
    // Idempotent: a key already recorded is never written again.
    ref.watch(milestoneSyncProvider);
    // And the one number each circle knows about this account: the days it
    // kept, recomputed here from its own day documents and written only when
    // the circle does not already hold it.
    ref.watch(circleSyncProvider);

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
            bottom: MediaQuery.of(context).padding.bottom + kBottomBarHeight,
          ),
        ),
        child: navigationShell,
      ),
      // The bar floats over the content, and the content showed through
      // beneath it: feature tiles half-visible under the pill. A scrim now
      // darkens the bottom of the screen, clear at its top edge and near
      // midnight behind the bar, so whatever runs under it fades away
      // instead of competing with it.
      bottomNavigationBar: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned(
            left: 0,
            right: 0,
            top: -96,
            bottom: 0,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      AppColors.midnight.withValues(alpha: 0),
                      AppColors.midnight.withValues(alpha: 0.55),
                      AppColors.midnight.withValues(alpha: 0.92),
                    ],
                    stops: const <double>[0, 0.45, 1],
                  ),
                ),
              ),
            ),
          ),
          _BottomBar(
            index: navigationShell.currentIndex,
            onTap: (int index) => _openTab(index),
          ),
        ],
      ),
    );
  }
}

/// Height of the floating navigation bar, including its margin.
///
/// Exported because every screen has to pad its own content by this much: the
/// bar is translucent and the content runs underneath it, so without the
/// padding the last item on each screen sits under the glass, unreachable.
const double kBottomBarHeight = _barHeight + 22 + Insets.lg;

/// The bar itself, inside that height.
const double _barHeight = 54;

/// Its width. Three tabs need no more than this, and a bar that spans the
/// screen reads as a toolbar rather than as a control you could pick up.
const double _barWidth = 300;

/// How far the lens stands proud of the bar, top and bottom. It is a bubble
/// of glass resting on the bar, not a highlight painted inside it, so it is
/// taller than the bar and bulges past both edges.
const double _bulge = 7;

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

  /// True from the moment a finger lands on the bar until it lifts.
  bool _pressed = false;

  /// Whether the lens is glass right now: a finger is on the bar, or
  /// dragging it.
  bool get _active => _pressed || _drag != null;

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
    // A compact floating pill with a lens of glass riding over it — the
    // iOS 26 treatment. The lens sits *above* the tabs and refracts them:
    // the icon and label beneath it bend at its rim, the way print does
    // under a drop of water, and the rim itself splits the light into a
    // thin band of colour. That is what makes it read as a bubble rather
    // than as a lighter patch of bar.
    final BorderRadius pill = BorderRadius.circular(_barHeight / 2);
    // Lower than the safe area would put it: the pill overlaps the home
    // indicator's inset the way Instagram's bar does, with a small gap left.
    final double lift = MediaQuery.paddingOf(context).bottom > 0 ? 22 : 12;
    return SafeArea(
      top: false,
      bottom: false,
      child: Listener(
        // Raw pointer events rather than a gesture: these never enter the
        // arena, so watching for a press cannot steal a tab tap or the drag.
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 0, 14, lift),
          // heightFactor, or Center fills the whole bottom slot — which the
          // Scaffold offers at screen height — and the body is squeezed to
          // nothing.
          child: Center(
            heightFactor: 1,
            // The whole pill swells while a finger is on it and settles back
            // the moment it lifts — Instagram's bar does the same, and it is
            // what makes the glass read as something you are holding.
            child: AnimatedScale(
              // Gentle: a small swell, no bounce, and a slow settle. The
              // bigger, springy version read as a jolt under the thumb.
              scale: _active ? 1.06 : 1.0,
              alignment: Alignment.bottomCenter,
              duration: Duration(milliseconds: _active ? 340 : 520),
              curve: _active ? Curves.easeOutCubic : Curves.easeInOutCubic,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _barWidth),
                child: SizedBox(
                  width: double.infinity,
                  height: _barHeight,
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints c) {
                      final int count = AppShell._tabs.length;
                      final double slot = c.maxWidth / count;
                      return GestureDetector(
                        // Horizontal only, so a tap still reaches the tabs and
                        // a vertical drag still belongs to the page behind.
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragStart: (DragStartDetails d) =>
                            _moveTo(d.localPosition.dx, c.maxWidth),
                        onHorizontalDragUpdate: (DragUpdateDetails d) =>
                            _moveTo(d.localPosition.dx, c.maxWidth),
                        onHorizontalDragEnd: (DragEndDetails _) => _release(),
                        onHorizontalDragCancel: _release,
                        child: Stack(
                          // The lens is taller than the bar and must not be
                          // cut off where it stands proud of it.
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            // The pane: frosted, with a cast shadow outside its
                            // clip — the shadow is what separates the glass from
                            // the page behind it.
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: pill,
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.30,
                                      ),
                                      blurRadius: 22,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: pill,
                                  child: BackdropFilter(
                                    filter: ui.ImageFilter.blur(
                                      sigmaX: 34,
                                      sigmaY: 34,
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: <Color>[
                                            AppColors.navyElevated.withValues(
                                              alpha: 0.58,
                                            ),
                                            AppColors.navy.withValues(
                                              alpha: 0.72,
                                            ),
                                          ],
                                        ),
                                        borderRadius: pill,
                                      ),
                                      child: const DecoratedBox(
                                        decoration: ShapeDecoration(
                                          shape: _GlassSurface(),
                                        ),
                                        child: SizedBox.expand(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Row(
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
                            ),
                            // The lens, over the tabs. It takes no touches: what
                            // you press is the tab under the glass.
                            //
                            // Two states. At rest it is the quiet thing: a
                            // slightly lighter pill inset in the bar, marking
                            // the tab and nothing more. The moment a finger is
                            // on the bar it becomes glass — swells past the
                            // bar's edges, bends what is behind it, catches the
                            // light — and follows the finger; and when the
                            // finger lifts it settles back into the pill. The
                            // glass is for the moving, not for the looking.
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(end: _active ? 1 : 0),
                              // Unhurried both ways, so the glass and the
                              // swell arrive together instead of snapping.
                              duration: Duration(
                                milliseconds: _active ? 320 : 520,
                              ),
                              curve: Curves.easeInOutCubic,
                              builder:
                                  (
                                    BuildContext context,
                                    double glass,
                                    Widget? _,
                                  ) => TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      end: _drag ?? index.toDouble(),
                                    ),
                                    // While a finger is on it the lens tracks
                                    // exactly, with no easing — anything else feels
                                    // like lag. It springs only once released.
                                    duration: _drag == null
                                        ? const Duration(milliseconds: 460)
                                        : Duration.zero,
                                    curve: Curves.easeOutBack,
                                    builder: (BuildContext context, double value, Widget? _) {
                                      // Distance still to run: 1 at the moment it
                                      // sets off, 0 once it has settled.
                                      final double travel = (value - index)
                                          .abs()
                                          .clamp(0.0, 1.0);
                                      // Stretches along its travel and gives a
                                      // little on the other axis, the way a soft
                                      // body would; and swells a touch under a
                                      // finger.
                                      final double sx =
                                          (1 + travel * 0.20) *
                                          (1 + glass * 0.06);
                                      final double sy =
                                          (1 - travel * 0.07) *
                                          (1 + glass * 0.06);
                                      final Rect rest = Rect.fromLTWH(
                                        slot * value + 4,
                                        5,
                                        slot - 8,
                                        _barHeight - 10,
                                      );
                                      final Rect bubble = Rect.fromLTWH(
                                        slot * value + 2,
                                        -_bulge,
                                        slot - 4,
                                        _barHeight + _bulge * 2,
                                      );
                                      final Rect lens = Rect.lerp(
                                        rest,
                                        bubble,
                                        glass,
                                      )!;
                                      return Positioned.fromRect(
                                        rect: lens,
                                        child: IgnorePointer(
                                          child: Transform.scale(
                                            scaleX: sx,
                                            scaleY: sy,
                                            child: Stack(
                                              children: <Widget>[
                                                // Real refraction, where the device
                                                // can do it, and only while there is
                                                // glass to refract with. Paints
                                                // nothing where it cannot, and the
                                                // painted glass carries it.
                                                if (glass > 0.02)
                                                  Positioned.fill(
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            lens.height / 2,
                                                          ),
                                                      child: RefractingGlass(
                                                        strength: 0.30 * glass,
                                                        light: glass,
                                                      ),
                                                    ),
                                                  ),
                                                Positioned.fill(
                                                  child: _GlassLens(
                                                    glass: glass,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
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
  const _GlassSurface({this.rim = 0.42, this.sheen = 0.09, this.fringe = 0.10});

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

/// The painted lens, from resting pill to glass.
///
/// [glass] is 0 at rest and 1 in motion. At rest this is the whole lens: a
/// flat, slightly lighter pill with no edge to speak of. As it becomes glass
/// the fill thins to almost nothing — the shader beneath supplies the body —
/// and a lit rim, a band of colour at the curve and a lift shadow come up.
class _GlassLens extends StatelessWidget {
  const _GlassLens({required this.glass});

  final double glass;

  @override
  Widget build(BuildContext context) {
    final double g = glass.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final BorderRadius radius = BorderRadius.circular(c.maxHeight / 2);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                AppColors.cream.withValues(alpha: 0.12 + g * 0.02),
                AppColors.cream.withValues(alpha: 0.11 - g * 0.07),
                Color.lerp(
                  AppColors.cream.withValues(alpha: 0.10),
                  AppColors.gold.withValues(alpha: 0.06),
                  g,
                )!,
              ],
            ),
            border: Border.all(
              color: AppColors.cream.withValues(alpha: 0.06 + g * 0.72),
              width: 1.3,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30 * g),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          // The same surface as the pane, a touch stronger: this is the nearer
          // piece of glass, so its edge catches more of the light. None of it
          // at rest.
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: _GlassSurface(rim: g, sheen: 0.20 * g, fringe: 0.55 * g),
            ),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.data, required this.selected, required this.onTap});

  final ({IconData icon, IconData active, String label}) data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The lens marks the selection now, so the old gold underline is gone —
    // two indicators for one state just fight each other.
    final Color color = selected ? AppColors.goldSoft : AppColors.mistFaint;
    return InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(selected ? data.active : data.icon, size: 20, color: color),
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
