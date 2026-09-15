import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/result.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_user.dart';
import '../../prayer_times/application/prayer_times_controller.dart';
import '../../prayer_times/domain/prayer.dart';
import '../../profile/domain/avatar.dart';
import '../../streaks/application/streak_controller.dart';
import '../../streaks/domain/prayer_day.dart';
import '../data/friends_repository.dart';
import '../domain/friend.dart';
import '../domain/inbox_item.dart';
import '../domain/jumuah.dart';
import '../domain/ramadan.dart';

/// The uid Friends acts as: a signed-in full account's, or null when signed
/// out or a guest.
///
/// Guests cannot use Friends at all — the rules refuse them — so every
/// provider below hangs off this one and goes quiet when it is null.
///
/// Whether the account is a guest is read from the profile document first
/// and the auth user second. `authStateChanges` does not fire when a guest
/// links an email and password, so the auth user can go on saying anonymous
/// until the next launch; the profile is rewritten the moment the link lands.
final Provider<String?> friendsUidProvider = Provider<String?>((Ref ref) {
  final User? user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  final AppUser? profile = ref.watch(appUserProvider).valueOrNull;
  final bool guest = profile?.isAnonymous ?? user.isAnonymous;
  return guest ? null : user.uid;
});

/// Everyone on my list, live. Empty, not loading, when there is no account
/// to have a list.
final StreamProvider<List<Friend>> friendsProvider =
    StreamProvider<List<Friend>>((Ref ref) {
      final String? uid = ref.watch(friendsUidProvider);
      if (uid == null) return Stream<List<Friend>>.value(const <Friend>[]);
      return ref.watch(friendsRepositoryProvider).watchFriends(uid);
    });

/// One friend's scoreboard, by uid. Null until they have published one.
///
/// Auto-disposed: each one is a Firestore listener, and a friend who has
/// removed you turns theirs into a permanent permission error. Letting them
/// go with the screen keeps neither the listener nor the error around.
final AutoDisposeStreamProviderFamily<FriendProgress?, String>
friendProgressProvider = StreamProvider.autoDispose
    .family<FriendProgress?, String>(
      (Ref ref, String uid) =>
          ref.watch(friendsRepositoryProvider).watchProgress(uid),
    );

/// My own code, created on first use. Null for guests, when signed out, and
/// while the profile has no name yet.
///
/// Waits for a name before creating anything: the name filed beside the code
/// is what a friend sees when they add it, and the code is created once.
/// Claiming it a moment before the profile loaded, or before the name prompt
/// was answered, would file it under a blank name for good. `selectAsync`
/// keeps this from re-running on every stats update — only a change of name
/// comes through, and a blank one is a null that keeps it waiting.
final FutureProvider<String?> myFriendCodeProvider = FutureProvider<String?>((
  Ref ref,
) async {
  final String? uid = ref.watch(friendsUidProvider);
  if (uid == null) return null;
  final String? name = await ref.watch(
    appUserProvider.selectAsync((AppUser? user) {
      final String trimmed = user?.displayName.trim() ?? '';
      return trimmed.isEmpty ? null : trimmed;
    }),
  );
  if (name == null) return null;
  return ref.watch(friendsRepositoryProvider).ensureCode(uid: uid, name: name);
});

/// Whether I have asked for my numbers to be withheld from friends.
///
/// Read off the profile, so the switch on the Friends screen and the
/// publisher below agree: the moment this is true the next publish carries
/// zeros, and "Quiet for now" is what every friend sees.
final Provider<bool> quietProvider = Provider<bool>(
  (Ref ref) => ref.watch(appUserProvider).valueOrNull?.quiet ?? false,
);

/// My latest milestone, or null when there is none yet.
final Provider<Milestone?> myMilestoneProvider = Provider<Milestone?>(
  (Ref ref) => ref.watch(appUserProvider).valueOrNull?.milestone,
);

/// What my friends would see of me right now, or null when there is nothing
/// to publish: signed out, a guest, no code yet, or the profile still loading.
///
/// `streak` is the stored counter, not the calendar-checked one: friends
/// compute `streakToday` from it and `lastCompletedDate` on their own phones,
/// so a chain that lapses overnight reads 0 for them without a publish.
final Provider<FriendProgress?> myProgressProvider = Provider<FriendProgress?>((
  Ref ref,
) {
  final String? uid = ref.watch(friendsUidProvider);
  if (uid == null) return null;
  final String? code = ref.watch(myFriendCodeProvider).valueOrNull;
  if (code == null) return null;
  final AppUser? user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return null;

  // Keyed to the day, so the tally is republished as zero at midnight even
  // if nothing else moves — otherwise yesterday's five would sit under
  // today's date on every friend's screen until the first prayer.
  //
  // Only a settled document for that very day counts. At the rollover the
  // day stream rebuilds for the new date and, while it loads, still hands
  // out yesterday's document as its last value; publishing that would file
  // yesterday's five under today's date — the exact lie the key exists to
  // prevent. An errored stream has nothing trustworthy to publish either.
  final String todayId = Fmt.dayId(ref.watch(todayProvider));
  final AsyncValue<PrayerDay> dayValue = ref.watch(todayPrayerDayProvider);
  if (dayValue.isLoading || dayValue.hasError) return null;
  final PrayerDay? day = dayValue.valueOrNull;
  if (day == null || day.dateId != todayId) return null;

  // Clamped to what the rules take (see FriendProgress' ceilings and
  // firestore.rules). A counter past a ceiling, a longest streak behind the
  // current one, or a day id in some older build's shape is refused — and the
  // publisher swallows a refusal, so friends would be left looking at a
  // scoreboard frozen at its old values with nothing on screen to say so.
  final UserStats stats = user.stats;
  final int streak = stats.currentStreak.clamp(0, FriendProgress.maxStreak);
  final FriendProgress full = FriendProgress(
    uid: uid,
    name: FriendName.clean(user.displayName),
    code: code,
    streak: streak,
    longestStreak: stats.longestStreak.clamp(streak, FriendProgress.maxStreak),
    totalPrayers: stats.totalPrayers.clamp(0, FriendProgress.maxTotalPrayers),
    totalTahajjud: stats.totalTahajjud.clamp(
      0,
      FriendProgress.maxTotalTahajjud,
    ),
    todayCompleted: day.completedCount.clamp(0, PrayerId.obligatory.length),
    todayDate: todayId,
    // The confirmed date, never the carried one. See
    // `UserStats.lastConfirmedDate`: the stored `lastCompletedDate` also
    // advances across days on which nothing was prayed, and publishing it
    // would put a pair on this scoreboard — a chain still alive beside a tally
    // of zero, two days running — that no other account can produce.
    lastCompletedDate: _dayIdOrNull(stats.lastConfirmedDate),
    // The small copy, never the big one. A friend's card draws this at 44
    // points, and the 512-pixel avatar is several times the data for pixels
    // their screen could not show — data their phone pays for on every
    // scoreboard read, not just once.
    //
    // Held to what the rules take, like every counter above it. A picture past
    // the ceiling cannot have come from this app, and publishing one would be
    // refused — silently — taking the whole scoreboard down with it.
    //
    // The value is copied straight from the profile, so it changes only when
    // the person changes their picture. The publisher compares maps and will
    // send exactly one write for that, then go quiet again.
    photo: _friendsCopy(user),
    // The milestone as recorded on the profile, whatever its age. Friends
    // decide whether it is still fresh; the cheer count below needs the key
    // for as long as the milestone stands.
    milestone: user.milestone,
    // How Ramadan is going, derived for today from the private record and
    // present only during Ramadan — the key comes off the document the day
    // the month ends, because the document is replaced wholesale.
    ramadan: ref.watch(isRamadanProvider)
        ? ref.watch(ramadanProvider).share(todayId)
        : null,
  );

  // Going quiet is decided here, on the way out, and not on any screen.
  // What is published in its place is a document of zeros with no milestone
  // and no Ramadan line, so the server holds nothing a friend's phone could
  // show; hiding the numbers on the reading side alone would leave them in
  // the document for any client to fetch.
  return user.quiet ? full.silenced() : full;
});

/// The picture a friend's scoreboard should carry.
///
/// Normally the small copy the crop editor wrote. The fallback is for the
/// accounts that set a picture before that editor existed: they have only the
/// old field, which was already held to the progress ceiling when it was
/// stored and is therefore still publishable. Without it their friends would
/// watch a face they have seen for weeks turn back into initials, for no
/// reason they could name, on the day this shipped.
String? _friendsCopy(AppUser user) {
  if (Avatar.isUsableThumb(user.photoThumb)) return user.photoThumb;
  final String? legacy = user.photo;
  return Avatar.isUsable(legacy) &&
          legacy!.length <= FriendProgress.maxPhotoChars
      ? legacy
      : null;
}

/// A stored day id, or null when it is not one the rules would take.
///
/// This app writes "2026-09-14" and so does the Cloud Function that recomputes
/// the streak, but a value in any other shape — from an older build, or a
/// half-written document — would be published once and refused from then on.
String? _dayIdOrNull(String? value) =>
    value != null && FriendProgress.dayIdPattern.hasMatch(value) ? value : null;

/// Pushes [myProgressProvider] to Firestore whenever it changes. Watched once
/// from the app shell, like the widget sync.
///
/// Every prayer confirmation moves the stats, the day document and therefore
/// this, in quick succession; the publisher coalesces those into one write
/// and never sends two within two seconds. It also skips a publish when
/// nothing a friend would see has changed, so a rebuild is not a write.
final Provider<void> progressPublisherProvider = Provider<void>((Ref ref) {
  final FriendProgress? progress = ref.watch(myProgressProvider);
  if (progress == null) return;
  ref.watch(_publisherProvider).schedule(progress);
});

final Provider<_ProgressPublisher> _publisherProvider =
    Provider<_ProgressPublisher>((Ref ref) {
      final _ProgressPublisher publisher = _ProgressPublisher(
        ref.watch(friendsRepositoryProvider),
      );
      ref.onDispose(publisher.dispose);
      return publisher;
    });

/// Whether two published documents would read the same on a friend's phone.
///
/// `mapEquals` compares values with `==`, and a nested map — the milestone,
/// the Ramadan line — is only ever equal to itself. Comparing with it would
/// see a change on every rebuild while either was present, and the throttle
/// would write the same scoreboard every two seconds for a week.
bool _sameFields(Object? a, Object? b) {
  if (a is Map<String, Object?> && b is Map<String, Object?>) {
    if (a.length != b.length) return false;
    for (final MapEntry<String, Object?> entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!_sameFields(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_sameFields(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// The throttle and the memory of what was last sent. Lives in its own
/// provider so the state survives every rebuild of [progressPublisherProvider].
class _ProgressPublisher {
  _ProgressPublisher(this._repo);

  final FriendsRepository _repo;

  /// The least time between two publishes.
  static const Duration _gap = Duration(seconds: 2);

  /// The fields last handed to Firestore, or null if the last attempt failed
  /// — in which case the next change, even back to these values, is sent.
  Map<String, Object?>? _published;

  FriendProgress? _pending;
  Timer? _timer;
  DateTime? _sentAt;

  void schedule(FriendProgress next) {
    if (_sameFields(next.toMap(), _published)) {
      // Back to what friends already see, possibly before a scheduled send
      // went out. There is nothing left to send.
      _pending = null;
      return;
    }
    _pending = next;
    // A send is already on its way; it takes whatever is pending when it runs.
    if (_timer != null) return;

    // Immediately when idle, so the first confirmation of the day reaches
    // friends at once; otherwise at the two-second mark.
    final DateTime? last = _sentAt;
    final Duration wait = last == null
        ? Duration.zero
        : _gap - DateTime.now().difference(last);
    _timer = Timer(wait.isNegative ? Duration.zero : wait, _flush);
  }

  void _flush() {
    _timer = null;
    final FriendProgress? progress = _pending;
    _pending = null;
    if (progress == null) return;

    final Map<String, Object?> values = progress.toMap();
    _published = values;
    _sentAt = DateTime.now();
    unawaited(
      _repo.publishProgress(progress).catchError((Object error) {
        // Forgotten so the next change retries. A failure here is a rules or
        // network problem, never something the person can act on, so it is
        // logged rather than shown.
        if (identical(_published, values)) _published = null;
        debugPrint('Layla Pro: progress not published ($error)');
      }),
    );
  }

  void dispose() => _timer?.cancel();
}

// ── Milestones ──────────────────────────────────────────────────────────

/// Every milestone the stats have crossed as of [today].
///
/// The streak is the calendar-checked reading, the one friends are shown:
/// the stored counter is never decayed by anything on this plan, so it goes
/// on saying a hundred for weeks after a chain broke.
Set<MilestoneKey> _crossed(UserStats stats, DateTime today) =>
    MilestoneKey.crossedBy(
      streak: stats.streakOn(today),
      totalPrayers: stats.totalPrayers,
      totalTahajjud: stats.totalTahajjud,
    );

/// The milestone that should be recorded now, or null when the profile
/// already says everything the stats do.
///
/// Pure, and separate from the write below so the thresholds can be checked
/// against real stats without a Firestore: 99 days is nothing, 100 is
/// `streak100`, and a document that already holds `streak365` is not moved
/// back to `streak100` when the chain breaks and climbs again.
final Provider<MilestoneKey?> milestoneDueProvider = Provider<MilestoneKey?>((
  Ref ref,
) {
  if (ref.watch(friendsUidProvider) == null) return null;
  final AppUser? user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return null;
  return Milestone.next(
    crossed: _crossed(user.stats, ref.watch(todayProvider)),
    current: user.milestone,
    reached: user.milestonesReached,
  );
});

/// Writes the milestone [milestoneDueProvider] says is due. Watched once from
/// the app shell, next to the publisher that copies it onto the scoreboard.
///
/// Nothing is written when nothing is due, which is every launch but the
/// one on which a threshold was crossed: the profile records every key it
/// has ever written, and `Milestone.next` never offers one of those again.
final Provider<void> milestoneSyncProvider = Provider<void>((Ref ref) {
  final MilestoneKey? due = ref.watch(milestoneDueProvider);
  if (due == null) return;
  final AppUser? user = ref.read(appUserProvider).valueOrNull;
  if (user == null) return;
  ref
      .watch(_milestoneWriterProvider)
      .record(key: due, crossed: _crossed(user.stats, ref.read(todayProvider)));
});

final Provider<_MilestoneWriter> _milestoneWriterProvider =
    Provider<_MilestoneWriter>(
      (Ref ref) => _MilestoneWriter(ref.watch(friendsRepositoryProvider)),
    );

/// The memory of the key last written this launch, kept outside the provider
/// above so it survives every rebuild of it.
///
/// A write the rules refuse reverts the local snapshot, the profile stream
/// re-delivers a document without the key, and the sync would otherwise
/// write it again on every such round trip. One attempt per key per launch;
/// the next launch tries again.
class _MilestoneWriter {
  _MilestoneWriter(this._repo);

  final FriendsRepository _repo;

  MilestoneKey? _attempted;

  void record({required MilestoneKey key, required Set<MilestoneKey> crossed}) {
    if (_attempted == key) return;
    _attempted = key;
    unawaited(
      _repo
          .recordMilestone(key: key, crossed: crossed)
          .catchError(
            (Object error) =>
                debugPrint('Layla Pro: milestone not recorded ($error)'),
          ),
    );
  }
}

/// How many friends have said MashaAllah to my latest milestone, live. Zero
/// when there is no milestone — the count is always about the current one,
/// so it starts again at zero with each.
final StreamProvider<int> cheersReceivedProvider = StreamProvider<int>((
  Ref ref,
) {
  final String? uid = ref.watch(friendsUidProvider);
  final Milestone? milestone = ref.watch(myMilestoneProvider);
  if (uid == null || milestone == null) return Stream<int>.value(0);
  return ref
      .watch(friendsRepositoryProvider)
      .watchCheers(uid: uid, key: milestone.key);
});

// ── The inbox ───────────────────────────────────────────────────────────

/// Everything friends have sent me that I have not dismissed, newest first.
/// Empty, not loading, when there is no account to have an inbox.
final StreamProvider<List<InboxItem>> inboxProvider =
    StreamProvider<List<InboxItem>>((Ref ref) {
      final String? uid = ref.watch(friendsUidProvider);
      if (uid == null) {
        return Stream<List<InboxItem>>.value(const <InboxItem>[]);
      }
      return ref.watch(friendsRepositoryProvider).watchInbox(uid);
    });

// ── Jumu'ah ─────────────────────────────────────────────────────────────

/// Whether today is Friday, off the same clock as everything else.
final Provider<bool> isFridayProvider = Provider<bool>(
  (Ref ref) => ref.watch(todayProvider).weekday == DateTime.friday,
);

/// Which masjid [uid] is going to this Friday, or null when they have not
/// said — or said for a Friday that has passed. Works for my own uid too.
///
/// Auto-disposed for the same reason a friend's scoreboard is: a friend who
/// has removed me turns this into a permission error that must not outlive
/// the screen. Keyed to the day so a plan for last Friday drops off at
/// midnight on its own.
final AutoDisposeStreamProviderFamily<Jumuah?, String> jumuahProvider =
    StreamProvider.autoDispose.family<Jumuah?, String>((Ref ref, String uid) {
      final DateTime today = ref.watch(todayProvider);
      return ref
          .watch(friendsRepositoryProvider)
          .watchJumuah(uid)
          .map(
            (Jumuah? plan) => plan != null && plan.isFor(today) ? plan : null,
          );
    });

// ── Prayers together ────────────────────────────────────────────────────

/// Where the count with one friend started, or null before it has been
/// written. Auto-disposed with the card that reads it.
final AutoDisposeStreamProviderFamily<FriendMeta?, String> friendMetaProvider =
    StreamProvider.autoDispose.family<FriendMeta?, String>((
      Ref ref,
      String friendUid,
    ) {
      if (ref.watch(friendsUidProvider) == null) {
        return Stream<FriendMeta?>.value(null);
      }
      return ref.watch(friendsRepositoryProvider).watchMeta(friendUid);
    });

/// When the friendship with [friendUid] was made, off my list.
DateTime? _friendSince(Ref ref, String friendUid) => ref.watch(
  friendsProvider.select((AsyncValue<List<Friend>> value) {
    for (final Friend friend in value.valueOrNull ?? const <Friend>[]) {
      if (friend.uid == friendUid) return friend.since;
    }
    return null;
  }),
);

/// "N prayers together": everything either of us has prayed since we became
/// friends, or null when there is no number to show.
///
/// Null while either side is quiet — a quiet friend publishes zeros, and
/// their zeros must not be read as a count — and until the start of the
/// count is on record. The record is written here, the first time this phone
/// sees the friend's scoreboard, because that is the only moment both totals
/// are in hand; a friendship made again after a removal starts a new count,
/// which is what `since` being later than the record's stamp means.
final AutoDisposeProviderFamily<int?, String> togetherProvider = Provider
    .autoDispose
    .family<int?, String>((Ref ref, String friendUid) {
      if (ref.watch(friendsUidProvider) == null) return null;
      if (ref.watch(quietProvider)) return null;
      final FriendProgress? theirs = ref
          .watch(friendProgressProvider(friendUid))
          .valueOrNull;
      if (theirs == null || theirs.quiet) return null;

      final AsyncValue<FriendMeta?> metaValue = ref.watch(
        friendMetaProvider(friendUid),
      );
      if (metaValue.isLoading || metaValue.hasError) return null;
      final FriendMeta? meta = metaValue.valueOrNull;

      final int myTotal = ref
          .watch(userStatsProvider)
          .totalPrayers
          .clamp(0, FriendProgress.maxTotalPrayers);

      final DateTime? since = _friendSince(ref, friendUid);
      final DateTime? at = meta?.at;
      final bool renewed =
          meta != null && since != null && at != null && since.isAfter(at);
      if (meta == null || renewed) {
        // Fire-and-forget, and the repository swallows its own failures:
        // nothing on screen is waiting for this, and the next look at the
        // card tries again. The stream re-delivers the document the moment
        // it is applied locally, which is what fills the line in.
        unawaited(
          ref
              .read(friendsRepositoryProvider)
              .writeMeta(
                friendUid: friendUid,
                myStartTotal: myTotal,
                theirStartTotal: theirs.totalPrayers,
              ),
        );
        return null;
      }
      return FriendMeta.together(
        myTotal: myTotal,
        myStartTotal: meta.myStartTotal,
        theirTotal: theirs.totalPrayers,
        theirStartTotal: meta.theirStartTotal,
      );
    });

// ── Ramadan and Eid ─────────────────────────────────────────────────────

/// Whether the Hijri month is Ramadan, off the same clock as everything else.
final Provider<bool> isRamadanProvider = Provider<bool>(
  (Ref ref) => HijriDates.isRamadan(ref.watch(todayProvider)),
);

/// The Hijri year today falls in, for keying a Ramadan record and an Eid.
final Provider<int> hijriYearProvider = Provider<int>(
  (Ref ref) => HijriDates.yearOf(ref.watch(todayProvider)),
);

/// My own Ramadan record for this year: what is stored when it is this
/// year's, and an empty record otherwise. Never null, so the card and the
/// publisher can read it without a case for "none yet".
final Provider<RamadanRecord> ramadanProvider = Provider<RamadanRecord>((
  Ref ref,
) {
  final int year = ref.watch(hijriYearProvider);
  final RamadanRecord? stored = ref.watch(appUserProvider).valueOrNull?.ramadan;
  return stored?.forYear(year) ?? RamadanRecord(year: year);
});

/// Which Eid today is: 1 for al-Fitr on 1 Shawwal, 2 for al-Adha on 10
/// Dhul-Hijjah, null on every other day of the year.
final Provider<int?> eidTodayProvider = Provider<int?>(
  (Ref ref) => HijriDates.eidOn(ref.watch(todayProvider)),
);

/// Whether today's Eid greeting has already gone out to my friends. False on
/// any day that is not Eid.
final Provider<bool> eidSentProvider = Provider<bool>((Ref ref) {
  final int? eid = ref.watch(eidTodayProvider);
  if (eid == null) return false;
  final Set<String> sent =
      ref.watch(appUserProvider).valueOrNull?.eidSent ?? const <String>{};
  return sent.contains(HijriDates.eidKey(ref.watch(todayProvider), eid));
});

final NotifierProvider<RamadanActions, AsyncValue<void>>
ramadanActionsProvider = NotifierProvider<RamadanActions, AsyncValue<void>>(
  RamadanActions.new,
);

/// The two ticks on the Ramadan card. Each rewrites the private record; the
/// publisher notices and sends today's flags on to friends. A failure is left
/// in `state.error` for a snackbar, as the other controllers leave theirs.
class RamadanActions extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue<void>.data(null);

  /// "I fasted today", on or off. Counts one fast per day however often it
  /// is pressed.
  Future<void> setFastedToday(bool fasted) => _save(
    (RamadanRecord record, String today) => record.withFasted(today, fasted),
  );

  /// "Taraweeh tonight", on or off.
  Future<void> setTaraweehTonight(bool prayed) => _save(
    (RamadanRecord record, String today) => record.withTaraweeh(today, prayed),
  );

  Future<void> _save(
    RamadanRecord Function(RamadanRecord record, String today) change,
  ) async {
    final RamadanRecord before = ref.read(ramadanProvider);
    final RamadanRecord after = change(
      before,
      Fmt.dayId(ref.read(todayProvider)),
    );
    if (after == before) return;
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(
      () => ref.read(friendsRepositoryProvider).setRamadan(after),
    );
  }
}

// ── Actions ─────────────────────────────────────────────────────────────

/// Adding and removing friends, and everything else a person does on the
/// Friends screen, with the busy and error state a screen needs.
///
/// `add` hands back the new [Friend], or null when it failed — the reason is
/// then in `state.error`: a [FriendAddException] for anything the person can
/// act on, otherwise whatever Firestore threw. The rest report nothing and
/// leave any failure in `state.error` the same way, which is where the
/// screens already look after `remove`.
final NotifierProvider<FriendsActions, AsyncValue<void>>
friendsActionsProvider = NotifierProvider<FriendsActions, AsyncValue<void>>(
  FriendsActions.new,
);

class FriendsActions extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue<void>.data(null);

  FriendsRepository get _repo => ref.read(friendsRepositoryProvider);

  /// My name as friends see it: cleaned the way every copy of it is.
  String get _myName =>
      FriendName.clean(ref.read(appUserProvider).valueOrNull?.displayName);

  Future<Friend?> add(String code) async {
    state = const AsyncValue<void>.loading();
    Friend? added;
    state = await AsyncValue.guard(() async {
      added = await _repo.addByCode(code);
    });
    return state.hasError ? null : added;
  }

  Future<void> remove(String uid) => _run(() => _repo.remove(uid));

  /// Withholds my numbers from friends, or shows them again.
  Future<void> setQuiet(bool quiet) => _run(() => _repo.setQuiet(quiet));

  /// MashaAllah on a friend's milestone. Saying it twice counts once.
  Future<void> cheer(String friendUid, MilestoneKey key) =>
      _run(() => _repo.cheer(friendUid: friendUid, key: key));

  /// Sends a friend one of the app's own passages, by its `Comfort.id`.
  Future<void> sendVerse(String friendUid, String comfortId) => _run(
    () => _repo.sendVerse(
      friendUid: friendUid,
      fromName: _myName,
      comfortId: comfortId,
    ),
  );

  /// Eid Mubarak to everyone on my list, once per Eid.
  ///
  /// Nothing happens on a day that is not Eid, or on an Eid the greeting has
  /// already gone out for — the profile remembers, so a relaunch does not
  /// send it twice. The list has to have loaded: a greeting sent to nobody
  /// would be recorded as sent.
  Future<void> sendEid() => _run(() async {
    final int? eid = ref.read(eidTodayProvider);
    if (eid == null || ref.read(eidSentProvider)) return;
    final List<Friend>? friends = ref.read(friendsProvider).valueOrNull;
    if (friends == null) {
      throw const AppFailure(
        'Your friends are still loading. Try again in a moment.',
        code: 'friends-loading',
      );
    }
    await _repo.sendEid(
      friendUids: <String>[for (final Friend friend in friends) friend.uid],
      fromName: _myName,
      eidKey: HijriDates.eidKey(ref.read(todayProvider), eid),
    );
  });

  /// Takes an item off my inbox for good.
  Future<void> dismissInbox(String itemId) =>
      _run(() => _repo.dismissInbox(itemId));

  /// Names the masjid for the coming Friday — today, when today is Friday.
  Future<void> setJumuah(String masjid) => _run(
    () => _repo.setJumuah(
      masjid: masjid,
      date: Jumuah.comingFridayId(ref.read(todayProvider)),
    ),
  );

  /// Runs one action with the busy state up; the failure, if any, is left in
  /// `state.error` for a snackbar.
  Future<void> _run(Future<void> Function() action) async {
    state = const AsyncValue<void>.loading();
    state = await AsyncValue.guard(action);
  }
}
