import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../prayer_lock/application/prayer_lock_sync.dart';
import '../../prayer_lock/application/prayer_lock_controller.dart';
import '../../prayer_lock/domain/prayer_session.dart';
import '../../prayer_times/application/prayer_times_controller.dart';
import '../../prayer_times/domain/prayer.dart';
import '../../streaks/application/streak_controller.dart';
import '../../streaks/domain/prayer_day.dart';
import '../../../core/config/platform_features.dart';
import '../../../core/widgets/noor_globe.dart';
import '../data/widget_bridge.dart';
import '../domain/widget_snapshot.dart';
import 'live_activity_toggle.dart';
import 'widget_theme_store.dart';

/// Builds the snapshot the widgets render.
///
/// Recomputed whenever the schedule, the day's progress, the streak or the
/// lock state changes — not on the clock tick. Countdowns tick inside SwiftUI,
/// so republishing every second would be pure battery cost for no visible gain.
final Provider<WidgetSnapshot?>
widgetSnapshotProvider = Provider<WidgetSnapshot?>((Ref ref) {
  final PrayerSchedule? schedule = ref
      .watch(prayerScheduleProvider)
      .valueOrNull;
  final PrayerMoment? moment = ref.watch(prayerMomentProvider).valueOrNull;
  if (schedule == null || moment == null) return null;

  final PrayerDay day =
      ref.watch(todayPrayerDayProvider).valueOrNull ??
      PrayerDay.empty(Fmt.dayId(DateTime.now()));
  // The streak as it stands today, not as it was last written: a chain
  // broken by a missed day must read 0 on the Lock Screen too. Keyed to the
  // day so the widget is republished at midnight even if nothing else moves.
  //
  // This is her own streak, carried across a prayer pause exactly as the app
  // promises — and it is the one place the pause stays faintly inferable. No
  // key here carries it (see `WidgetSnapshot.toMap`: no cycle, no gender, no
  // excused, and `confirmed` is empty as on any unprayed day), but somebody
  // who picked her phone up on two successive evenings would see a live
  // streak beside a tally of zero twice, which an ordinary week cannot
  // produce. The alternative is publishing the confirmed date's streak here
  // too, which would show her a zero on her own Lock Screen and tell her the
  // chain she was promised was safe had gone. Kept deliberately: a stranger
  // holding her phone across two days is a narrower exposure than lying to
  // her about her own streak, and the friends scoreboard — which reaches
  // people who are not holding the phone — is closed outright.
  final DateTime today = ref.watch(todayProvider);
  final int streak = ref.watch(userStatsProvider).streakOn(today);
  final PrayerSession? session = ref.watch(activeSessionProvider);
  final bool blocking = ref.watch(appBlockingEnabledProvider);
  final String city = ref.watch(placeProvider).valueOrNull?.city ?? '';

  final PrayerSlot? current = moment.current;

  return WidgetSnapshot(
    city: city.isEmpty ? 'Your location' : city,
    hijri: Fmt.hijri(DateTime.now()),
    latitude: schedule.latitude,
    longitude: schedule.longitude,
    prayers: WidgetSnapshot.prayersFrom(schedule),
    nextKey: moment.next.id.key,
    nextStartsAt: moment.next.start,
    currentKey: current?.id.key ?? '',
    // Before Fajr there is no running prayer, so the gauge measures the stretch
    // from yesterday's Isha instead of collapsing to zero.
    currentStartedAt:
        current?.start ?? moment.next.start.subtract(const Duration(hours: 8)),
    streak: streak,
    theme: ref.watch(widgetThemeProvider).id,
    completedToday: day.completedCount,
    totalToday: PrayerId.obligatory.length,
    locked: session != null && blocking,
    lockedPrayerLabel: session?.prayer.label ?? '',
    // Which five, not just how many — the tracker widget draws a tick per
    // prayer, and it has to be the right ones.
    confirmed: <String>{
      for (final PrayerId id in PrayerId.obligatory)
        if (day.recordFor(id).isCompleted) id.key,
    },
  );
});

/// Pushes each new snapshot across to iOS. Watched once from the app shell.
final Provider<void> widgetSyncProvider = Provider<void>((Ref ref) {
  if (!Have.homeScreenWidgets) return;

  final WidgetSnapshot? snapshot = ref.watch(widgetSnapshotProvider);
  if (snapshot == null) return;

  final WidgetBridge bridge = ref.watch(widgetBridgeProvider);

  // The Live Activity only exists while a prayer window is open — a permanent
  // one would be clutter on the Lock Screen. It is also the only surface that
  // can show the streak, since `Activity` carries state straight from the app
  // and needs no App Group.
  // The activity now carries the next prayer and today's times, not only
  // the lock, so it runs whenever the app does. iOS retires it on its own
  // after eight hours; the next launch starts it again.
  // Unless it has been switched off in Reminders & prayer focus, in which
  // case any activity still showing is ended now.
  if (Have.liveActivity) {
    if (ref.watch(liveActivityEnabledProvider)) {
      unawaited(bridge.startLiveActivity(snapshot));
    } else {
      unawaited(bridge.endLiveActivity());
    }
  }

  // Home-screen widgets compute their own times, but the streak and today's
  // progress live behind the login, so they have to be handed over. This also
  // redraws the widgets, so no separate reload is needed.
  unawaited(bridge.publishSnapshot(snapshot));

  // And the globe, which only the app can draw.
  //
  // Turned to the fraction of the day elapsed rather than to an animation
  // value: a widget cannot animate — WidgetKit paints still frames on a
  // timeline, there is no frame loop to run — so the honest version of "it
  // moves" is that the sphere is at the angle the hour says it should be, and
  // has visibly turned whenever you look again later.
  // Only iOS has a widget that draws it, and the frame is rendered before it
  // is sent — so leaving this to fail quietly on Android would burn a 640px
  // render every twenty minutes for a picture nobody can see.
  if (Have.liveActivity) unawaited(_publishGlobe(bridge, snapshot));
});

DateTime? _globePublishedAt;

Future<void> _publishGlobe(WidgetBridge bridge, WidgetSnapshot snapshot) async {
  final DateTime now = DateTime.now();
  // A frame every twenty minutes is as often as the turn is visible, and it
  // keeps the extension from being asked to redraw on every small change.
  if (_globePublishedAt != null &&
      now.difference(_globePublishedAt!) < const Duration(minutes: 20)) {
    return;
  }
  _globePublishedAt = now;
  final double turn =
      (now.hour * 3600 + now.minute * 60 + now.second) / 86400.0;

  final Uint8List? png = await renderGlobeFrame(
    size: 640,
    turn: turn,
    latitude: snapshot.latitude,
    longitude: snapshot.longitude,
  );
  if (png != null) await bridge.publishGlobe(png);
}
