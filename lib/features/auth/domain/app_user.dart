import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../cycle/domain/cycle.dart';
import '../../friends/domain/friend.dart';
import '../../friends/domain/ramadan.dart';
import '../../prayer_times/domain/prayer_settings.dart';
import '../../../core/utils/formatters.dart';

/// The two answers the onboarding gender question can produce.
///
/// Held in one place because `firestore.rules` refuses any third value, and a
/// refused write is silent — a typo here would not fail, it would simply mean
/// the prayer pause never appearing for somebody who needs it.
abstract final class Gender {
  static const String brother = 'brother';
  static const String sister = 'sister';

  static const Set<String> values = <String>{brother, sister};

  /// Whether [value] is an answer the profile may store.
  static bool isValid(String? value) => value != null && values.contains(value);

  static bool isSister(String? value) => value == sister;
}

/// Streak and prayer counters. The client updates these optimistically; the
/// `recalculateStreak` Cloud Function is the authority.
@immutable
class UserStats {
  const UserStats({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalPrayers = 0,
    this.totalTahajjud = 0,
    this.lastCompletedDate,
    this.lastConfirmedDate,
  });

  final int currentStreak;
  final int longestStreak;
  final int totalPrayers;
  final int totalTahajjud;

  /// "2026-08-20" — the last day the chain was carried, which is a finished
  /// day or a day the prayer pause covered. This is what [streakOn] reads, and
  /// carrying it onto a paused day is the whole mechanism by which a streak
  /// survives one. It is never published: see [lastConfirmedDate].
  final String? lastCompletedDate;

  /// "2026-08-20" — the last day all five prayers were actually confirmed.
  ///
  /// The half of [lastCompletedDate] that may leave this device. It can only
  /// name a day on which five of five were confirmed, so a scoreboard carrying
  /// it can never hold the pair "streak alive and nothing prayed" that no
  /// ordinary day produces. See `StreakStats.lastConfirmedDate`, where the
  /// reasoning and the one residual are written out.
  final String? lastConfirmedDate;

  /// The streak as it stands *today*, rather than as it was last written.
  ///
  /// `currentStreak` in Firestore only ever moves on a finished day, so a
  /// lapsed day leaves it untouched: skip Dhuhr, or simply do not open the app,
  /// and it goes on reporting three days of a chain that is already broken.
  /// Marking a prayer missed now zeroes it, but nothing fires when a window
  /// merely closes unremarked — so the reading is also checked against the
  /// calendar here.
  ///
  /// A chain is alive only if the last finished day was today or yesterday.
  /// Yesterday counts because today is still in progress.
  int streakOn(DateTime now) {
    final String? last = lastCompletedDate;
    if (last == null || currentStreak == 0) return 0;
    // Fmt.dayId, not a second implementation of the same format — this is
    // compared against a value the repository wrote with Fmt.dayId, and two
    // formatters that drift apart would break every comparison silently.
    final String today = Fmt.dayId(now);
    final String yesterday = Fmt.dayId(now.subtract(const Duration(days: 1)));
    return last == today || last == yesterday ? currentStreak : 0;
  }

  factory UserStats.fromMap(Map<String, Object?>? map) {
    if (map == null) return const UserStats();
    return UserStats(
      currentStreak: (map['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (map['longestStreak'] as num?)?.toInt() ?? 0,
      totalPrayers: (map['totalPrayers'] as num?)?.toInt() ?? 0,
      totalTahajjud: (map['totalTahajjud'] as num?)?.toInt() ?? 0,
      lastCompletedDate: map['lastCompletedDate'] as String?,
      // The same fallback as `StreakStats.fromMap`, and for the same reason:
      // before the pause existed the two dates were one fact, so an account
      // that predates the field still publishes its last real completion.
      lastConfirmedDate: map.containsKey('lastConfirmedDate')
          ? map['lastConfirmedDate'] as String?
          : map['lastCompletedDate'] as String?,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'totalPrayers': totalPrayers,
    'totalTahajjud': totalTahajjud,
    'lastCompletedDate': lastCompletedDate,
    'lastConfirmedDate': lastConfirmedDate,
  };
}

@immutable
class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photo,
    this.photoThumb,
    this.isAnonymous = false,
    this.settings = const PrayerSettings(),
    this.stats = const UserStats(),
    this.city = '',
    this.country = '',
    this.createdAt,
    this.gender,
    this.cycle = Cycle.none,
    this.quiet = false,
    this.milestone,
    this.milestonesReached = const <MilestoneKey>{},
    this.ramadan,
    this.eidSent = const <String>{},
  });

  final String uid;
  final String displayName;
  final String email;

  /// The profile picture as a base64 JPEG, or null for none.
  ///
  /// The picture itself, not a link to one: there is no Firebase Storage on
  /// this project, so it is stored inline on the user document and bounded by
  /// `Avatar.maxChars`. This replaced an unused `photoUrl` that nothing ever
  /// wrote — keeping both would have left the next reader guessing which one
  /// the avatar comes from.
  final String? photo;

  /// The small copy of the same picture, as a base64 JPEG, or null for none.
  ///
  /// Not a duplicate: this is the one every friend's phone downloads. The
  /// picture above is 512 pixels because it is drawn large on your own
  /// profile; this one is 128 because it is drawn at 44 points on a card in
  /// somebody else's list, and it is what `progress/{uid}.photo` is published
  /// from. Sending them the big one instead would be several times the data
  /// for pixels no friend's screen would ever show.
  ///
  /// Null on an account that set its picture before the crop editor shipped.
  /// Those are left alone rather than migrated: there is nothing to migrate
  /// *from* — a 256-pixel picture cannot be made into a sharper one — and the
  /// next time they choose a photo both fields are written together.
  final String? photoThumb;
  final bool isAnonymous;
  final PrayerSettings settings;
  final UserStats stats;
  final String city;
  final String country;
  final DateTime? createdAt;

  /// "brother" or "sister" — see [Gender]. Null on an account that onboarded
  /// before this was written to the profile at all.
  ///
  /// On the account rather than on the phone, and that is the whole point of
  /// it being here: the answer used to live only in SharedPreferences, which
  /// `AuthController.signOut` clears, so answering "sister" once did not
  /// survive signing out and back in — and with it went the only thing that
  /// decides whether the prayer pause is ever offered.
  final String? gender;

  /// The prayer pause, if one is on. See [Cycle] — the most private thing on
  /// this document, and this document is the only place it lives.
  final Cycle cycle;

  /// Whether the person has asked for their numbers to be withheld from
  /// friends. The publisher reads it and sends zeros — see
  /// `FriendProgress.quiet` for why the zeros go to the server.
  final bool quiet;

  /// The latest milestone the sync recorded, copied onto the scoreboard.
  /// Null when none has been, and for the instant between the write and the
  /// server stamping it.
  final Milestone? milestone;

  /// Every milestone ever recorded for this account, on `milestonesReached`.
  ///
  /// The document above holds one milestone; this is what stops an older one
  /// on another counter being recorded again once it has been replaced —
  /// see `Milestone.next`.
  final Set<MilestoneKey> milestonesReached;

  /// The owner's own Ramadan record, if one has been kept. Null outside
  /// Ramadan and before the first tick; a record from an earlier year is
  /// carried but read as empty by `ramadanProvider`.
  final RamadanRecord? ramadan;

  /// "1448-1" for each Eid the greeting has gone out for — the keys of
  /// `eidSent` whose value is true — so a relaunch on Eid does not send it
  /// again.
  final Set<String> eidSent;

  /// "Assalamu alaikum, Aden" — first word only, so long names don't wrap.
  String get firstName => displayName.trim().isEmpty
      ? 'friend'
      : displayName.trim().split(' ').first;

  /// One or two letters for the avatar circle.
  String get initials {
    final List<String> parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, Object?>> doc) {
    final Map<String, Object?> data = doc.data() ?? <String, Object?>{};
    final Map<String, Object?> location =
        (data['location'] as Map<String, Object?>?) ?? <String, Object?>{};
    return AppUser(
      uid: doc.id,
      displayName: data['displayName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      // Read as an Object? and tested, not cast: an older build could have
      // left something that is not a string here, and a cast would throw
      // inside a snapshot listener and take the whole profile stream with it.
      photo: data['photo'] is String ? data['photo'] as String : null,
      photoThumb: data['photoThumb'] is String
          ? data['photoThumb'] as String
          : null,
      isAnonymous: data['isAnonymous'] as bool? ?? false,
      settings: PrayerSettings.fromMap(
        data['settings'] as Map<String, Object?>?,
      ),
      stats: UserStats.fromMap(data['stats'] as Map<String, Object?>?),
      city: location['city'] as String? ?? '',
      country: location['country'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      // Both read as Object? and tested, never cast. These two decide whether
      // the app asks a woman to pray and whether it keeps her streak, and a
      // cast that threw in here would take the whole profile stream — every
      // screen in the app — down with it.
      gender:
          data['gender'] is String && Gender.isValid(data['gender']! as String)
          ? data['gender']! as String
          : null,
      cycle: Cycle.fromMap(
        data['cycle'] is Map<String, Object?>
            ? data['cycle'] as Map<String, Object?>
            : null,
      ),
      // The Friends fields, each tested rather than cast for the same reason
      // as the two above: a throw here takes the whole profile stream down.
      quiet: data['quiet'] == true,
      milestone: Milestone.fromMap(data['milestone']),
      milestonesReached: _milestoneKeys(data['milestonesReached']),
      ramadan: RamadanRecord.fromMap(data['ramadan']),
      eidSent: _trueKeys(data['eidSent']),
    );
  }

  /// A copy with some fields replaced.
  ///
  /// Clearing the picture needs [clearPhoto] rather than `photo: null`: an
  /// omitted argument and an explicit null are the same value here, so a plain
  /// `copyWith(photo: null)` would keep the old picture instead of removing
  /// it. That is the one call the avatar feature invites — an optimistic local
  /// clear while `AvatarController.remove` is still in flight — so it is named
  /// rather than left as a trap. It clears both sizes, because the two are
  /// one picture and a profile holding only its friends' copy would be a
  /// state nothing in the app knows how to draw.
  AppUser copyWith({
    String? displayName,
    String? photo,
    String? photoThumb,
    bool clearPhoto = false,
    PrayerSettings? settings,
    UserStats? stats,
    String? city,
    String? country,
  }) => AppUser(
    uid: uid,
    displayName: displayName ?? this.displayName,
    email: email,
    photo: clearPhoto ? null : (photo ?? this.photo),
    photoThumb: clearPhoto ? null : (photoThumb ?? this.photoThumb),
    isAnonymous: isAnonymous,
    settings: settings ?? this.settings,
    stats: stats ?? this.stats,
    city: city ?? this.city,
    country: country ?? this.country,
    createdAt: createdAt,
    // Carried across rather than offered as arguments. Neither is edited from
    // a screen — the gender comes from onboarding and the pause from its own
    // controller, both straight to Firestore — and dropping them here would
    // turn any optimistic local copy into one where no pause is on.
    gender: gender,
    cycle: cycle,
    // The Friends fields likewise: each is written straight to Firestore by
    // its own action, and a copy that dropped `quiet` would be a copy that
    // published the numbers.
    quiet: quiet,
    milestone: milestone,
    milestonesReached: milestonesReached,
    ramadan: ramadan,
    eidSent: eidSent,
  );
}

/// The milestone keys in a stored list, skipping anything that is not one.
Set<MilestoneKey> _milestoneKeys(Object? raw) => <MilestoneKey>{
  if (raw is List<Object?>)
    for (final Object? entry in raw)
      if (MilestoneKey.fromKey(entry is String ? entry : null)
          case final MilestoneKey key)
        key,
};

/// The keys of a stored map whose value is true, for a map used as a set.
Set<String> _trueKeys(Object? raw) => <String>{
  if (raw is Map<String, Object?>)
    for (final MapEntry<String, Object?> entry in raw.entries)
      if (entry.value == true) entry.key,
};
