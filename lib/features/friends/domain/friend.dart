import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';

/// The six-character code a person hands to a friend.
///
/// It is the only thing anyone ever shares: no email, no uid, no phone
/// number. The alphabet leaves out 0, O, 1 and I, because a code is read
/// aloud across a table or typed from a screenshot, and those four are the
/// ones that get misread. Stored without the hyphen; shown with one after the
/// third character so it reads as two short groups rather than one long one.
abstract final class FriendCode {
  static const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// How many characters a code has, stored form.
  static const int length = 6;

  static final Set<int> _units = alphabet.codeUnits.toSet();

  /// A fresh code. Thirty-two symbols to the sixth power is about a billion,
  /// so a clash on the first try is a curiosity, and the repository retries.
  ///
  /// [random] is for tests; production uses a secure source.
  static String generate([math.Random? random]) {
    final math.Random rand = random ?? math.Random.secure();
    return List<String>.generate(
      length,
      (_) => alphabet[rand.nextInt(alphabet.length)],
    ).join();
  }

  /// What someone typed, reduced to what a code can contain: uppercased, with
  /// the hyphen, spaces and any character outside the alphabet dropped, and
  /// cut at six. Lenient on purpose — a pasted "abc-234 " is the right code.
  static String normalize(String input) {
    final StringBuffer out = StringBuffer();
    for (final int unit in input.toUpperCase().codeUnits) {
      if (!_units.contains(unit)) continue;
      out.writeCharCode(unit);
      if (out.length == length) break;
    }
    return out.toString();
  }

  /// "ABC-234". Shorter input is shown as it is, so a code being typed can be
  /// echoed back without a stray hyphen.
  static String display(String code) {
    final String clean = normalize(code);
    if (clean.length <= 3) return clean;
    return '${clean.substring(0, 3)}-${clean.substring(3)}';
  }

  /// Six characters, every one of them in the alphabet.
  static bool isValid(String code) =>
      code.length == length && code.codeUnits.every(_units.contains);
}

/// A display name in the shape the security rules insist on: never blank,
/// never longer than forty characters.
///
/// One place rather than three. The same name is copied onto a friend code,
/// onto both sides of a friendship and onto the progress document, and each
/// of those rules refuses an empty name and anything past forty. A profile
/// with no name yet would otherwise turn every write into a permission error
/// the person can neither see nor act on, so it becomes [fallback] instead.
abstract final class FriendName {
  /// The longest name any Friends document carries; the rules refuse more.
  static const int maxLength = 40;

  /// What stands in for someone who has not given a name.
  static const String fallback = 'A friend';

  /// [name] trimmed, cut to [maxLength], and never empty.
  ///
  /// Cut by code point rather than by UTF-16 unit: `substring` can split a
  /// surrogate pair and leave half a character behind, which is not valid
  /// text to hand Firestore.
  static String clean(String? name) {
    final String trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return fallback;
    final List<int> runes = trimmed.runes.toList(growable: false);
    if (runes.length <= maxLength) return trimmed;
    return String.fromCharCodes(runes.take(maxLength));
  }
}

/// One or two letters for an avatar circle, the same way `AppUser.initials`
/// does it, so a friend's circle matches their own.
String _initialsOf(String name) {
  final List<String> parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((String p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
}

/// A person on someone's friends list: `friends/{uid}/list/{friendUid}`.
///
/// The name and code are copies taken when the friendship was made. The
/// user document is private, so a friend cannot read the live name from it —
/// the copy is what the list shows.
@immutable
class Friend {
  const Friend({
    required this.uid,
    required this.name,
    required this.code,
    this.since,
  });

  final String uid;
  final String name;
  final String code;

  /// When the friendship was made. Null for the instant between the local
  /// write and the server stamping it.
  final DateTime? since;

  String get initials => _initialsOf(name);

  factory Friend.fromDoc(DocumentSnapshot<Map<String, Object?>> doc) {
    final Map<String, Object?> data = doc.data() ?? <String, Object?>{};
    return Friend(
      uid: doc.id,
      name: FriendName.clean(data['name'] as String?),
      code: data['code'] as String? ?? '',
      since: (data['since'] as Timestamp?)?.toDate(),
    );
  }

  /// The document as written. A missing [since] becomes the server's clock,
  /// which is the only clock two phones agree on.
  Map<String, Object?> toMap() => <String, Object?>{
    'name': name,
    'code': code,
    'since': since == null
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(since!),
  };
}

/// The six things worth telling a friend about, and nothing smaller.
///
/// Held to six on purpose. A milestone sits on a friend's card for a week and
/// invites a "MashaAllah", so each one has to be rare enough that the word
/// still means something — a badge for every ten prayers would be noise, and
/// noise on this screen would make it a leaderboard. The stored string is the
/// enum's own name, which `firestore.rules` pins to exactly these six.
enum MilestoneKey {
  streak100,
  streak365,
  prayers1000,
  prayers5000,
  tahajjud1,
  tahajjud100;

  /// The stored form, on `users/{uid}.milestone`, `progress/{uid}.milestone`
  /// and every cheer.
  String get key => name;

  /// What a friend reads on the badge.
  String get label => switch (this) {
    MilestoneKey.streak100 => '100 days',
    MilestoneKey.streak365 => 'A year of prayer',
    MilestoneKey.prayers1000 => '1,000 prayers',
    MilestoneKey.prayers5000 => '5,000 prayers',
    MilestoneKey.tahajjud1 => 'First Tahajjud',
    MilestoneKey.tahajjud100 => '100 Tahajjud nights',
  };

  /// Which counter it is read off.
  MilestoneStat get stat => switch (this) {
    MilestoneKey.streak100 || MilestoneKey.streak365 => MilestoneStat.streak,
    MilestoneKey.prayers1000 ||
    MilestoneKey.prayers5000 => MilestoneStat.prayers,
    MilestoneKey.tahajjud1 ||
    MilestoneKey.tahajjud100 => MilestoneStat.tahajjud,
  };

  /// The reading of [stat] that crosses it.
  int get threshold => switch (this) {
    MilestoneKey.streak100 => 100,
    MilestoneKey.streak365 => 365,
    MilestoneKey.prayers1000 => 1000,
    MilestoneKey.prayers5000 => 5000,
    MilestoneKey.tahajjud1 => 1,
    MilestoneKey.tahajjud100 => 100,
  };

  /// A stored key read back, or null for anything that is not one of the
  /// six — a document written by a newer build must not throw in a listener.
  static MilestoneKey? fromKey(String? key) {
    for (final MilestoneKey value in values) {
      if (value.key == key) return value;
    }
    return null;
  }

  /// Every milestone these counters have crossed.
  ///
  /// [streak] is the calendar-checked reading (`UserStats.streakOn`), never
  /// the stored counter: a chain that lapsed last month must not cross a
  /// hundred on the strength of a number nothing has zeroed.
  static Set<MilestoneKey> crossedBy({
    required int streak,
    required int totalPrayers,
    required int totalTahajjud,
  }) => <MilestoneKey>{
    for (final MilestoneKey key in values)
      if (key.threshold <=
          switch (key.stat) {
            MilestoneStat.streak => streak,
            MilestoneStat.prayers => totalPrayers,
            MilestoneStat.tahajjud => totalTahajjud,
          })
        key,
  };
}

/// The three counters a milestone can be read off.
enum MilestoneStat { streak, prayers, tahajjud }

/// A milestone somebody reached, and when: `{ key, at }`.
///
/// Stored on the owner's own document and copied onto their scoreboard, where
/// friends see it for a week and can say MashaAllah. The copy is the same
/// shape as the original so the rules can hold both to it.
@immutable
class Milestone {
  const Milestone({required this.key, required this.at});

  /// How long a milestone stays on a friend's card. A week is long enough
  /// that a friend who opens the app on Fridays sees it, and short enough
  /// that the card does not become a trophy cabinet.
  static const Duration freshFor = Duration(days: 7);

  /// The six, in the order most people reach them, rarest last.
  ///
  /// Only ever consulted when several are crossed at once — the first launch
  /// after this shipped, for an account that already has years behind it, or
  /// the one prayer that finishes a hundredth day and is also the thousandth.
  /// The rarest becomes the one on the card; the rest are recorded as reached
  /// so they are never celebrated late.
  static const List<MilestoneKey> _byRarity = <MilestoneKey>[
    MilestoneKey.tahajjud1,
    MilestoneKey.streak100,
    MilestoneKey.prayers1000,
    MilestoneKey.tahajjud100,
    MilestoneKey.streak365,
    MilestoneKey.prayers5000,
  ];

  final MilestoneKey key;
  final DateTime at;

  /// Whether it is still shown, as of [now]. A clock ahead of the server's
  /// reads a fresh milestone as slightly in the future, and that is fresh.
  bool isFreshOn(DateTime now) => now.difference(at) < freshFor;

  bool get isFresh => isFreshOn(DateTime.now());

  /// The stored map read back, or null when it is not one this app wrote.
  ///
  /// Tested rather than cast, and strict about `at`: a milestone written a
  /// moment ago carries a server timestamp that the local snapshot still
  /// reports as null, and until the server has stamped it there is nothing to
  /// measure a week from. It reads as absent for that instant and arrives
  /// with the next snapshot.
  static Milestone? fromMap(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? key = raw['key'];
    final Object? at = raw['at'];
    final MilestoneKey? parsed = MilestoneKey.fromKey(
      key is String ? key : null,
    );
    if (parsed == null || at is! Timestamp) return null;
    return Milestone(key: parsed, at: at.toDate());
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'key': key.key,
    'at': Timestamp.fromDate(at),
  };

  /// The milestone to record now, or null when there is nothing new.
  ///
  /// [crossed] is what the counters say (see [MilestoneKey.crossedBy]);
  /// [current] is the one on the document; [reached] is every key ever
  /// recorded for this account. Three rules, each for a reason:
  ///
  /// Never the same key twice: the sync runs on every launch and every stats
  /// change, and a rewrite would move `at`, keep the badge fresh for ever and
  /// count every friend's cheer again.
  ///
  /// Never downwards on one counter: a year-long chain that breaks and climbs
  /// back to a hundred has already been past a hundred, and a recorded key
  /// implies every smaller one on the same counter — so the implication holds
  /// even for a document that predates the reached list.
  ///
  /// Never a key already reached on another counter: the document holds one
  /// milestone, so without the list a first Tahajjud recorded last year would
  /// be re-recorded the day the streak badge replaced it, and the two would
  /// take turns for good.
  static MilestoneKey? next({
    required Set<MilestoneKey> crossed,
    required Milestone? current,
    required Set<MilestoneKey> reached,
  }) {
    final Set<MilestoneKey> recorded = <MilestoneKey>{
      ...reached,
      if (current != null) current.key,
    };
    final Set<MilestoneKey> implied = <MilestoneKey>{
      for (final MilestoneKey done in recorded)
        for (final MilestoneKey key in MilestoneKey.values)
          if (key.stat == done.stat && key.threshold <= done.threshold) key,
    };
    final Set<MilestoneKey> fresh = crossed.difference(implied);
    if (fresh.isEmpty) return null;
    return _byRarity.lastWhere(fresh.contains);
  }

  @override
  bool operator ==(Object other) =>
      other is Milestone && other.key == key && other.at == at;

  @override
  int get hashCode => Object.hash(key, at);

  @override
  String toString() => 'Milestone(${key.key} at $at)';
}

/// What a friend may see of somebody's Ramadan: `progress/{uid}.ramadan`.
///
/// A count of fasts and two yes-or-nos for today, present only while the
/// Hijri month is Ramadan. Derived by the owner's phone from their own record
/// (`RamadanRecord`), which stays on the private document.
@immutable
class RamadanShare {
  const RamadanShare({
    required this.fasts,
    required this.fastingToday,
    required this.taraweeh,
    required this.date,
  });

  /// The most fasts a Ramadan can hold; the rules refuse more.
  static const int maxFasts = 30;

  final int fasts;
  final bool fastingToday;
  final bool taraweeh;

  /// "2027-02-20" — the day the two flags describe, written down for the
  /// same reason `FriendProgress.todayDate` is: a friend can be a day away.
  final String date;

  /// Whether the flags are about [now]'s date rather than an earlier one.
  bool isForDay(DateTime now) => date == Fmt.dayId(now);

  static RamadanShare? fromMap(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? fasts = raw['fasts'];
    final Object? date = raw['date'];
    if (date is! String || !FriendProgress.dayIdPattern.hasMatch(date)) {
      return null;
    }
    return RamadanShare(
      fasts: (fasts is num ? fasts.toInt() : 0).clamp(0, maxFasts),
      fastingToday: raw['fastingToday'] == true,
      taraweeh: raw['taraweeh'] == true,
      date: date,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'fasts': fasts,
    'fastingToday': fastingToday,
    'taraweeh': taraweeh,
    'date': date,
  };

  @override
  bool operator ==(Object other) =>
      other is RamadanShare &&
      other.fasts == fasts &&
      other.fastingToday == fastingToday &&
      other.taraweeh == taraweeh &&
      other.date == date;

  @override
  int get hashCode => Object.hash(fasts, fastingToday, taraweeh, date);
}

/// Where a friendship started counting: `friends/{uid}/meta/{friendUid}`.
///
/// Both totals as they stood the first time the owner's phone saw that
/// friend's scoreboard. "N prayers together" is everything either of you has
/// prayed since, which is a number that starts at zero the day you become
/// friends rather than a sum of two lifetimes. Owner-only, written once.
@immutable
class FriendMeta {
  const FriendMeta({
    required this.myStartTotal,
    required this.theirStartTotal,
    this.at,
  });

  final int myStartTotal;
  final int theirStartTotal;

  /// Server time of the write. Null for the instant before it is stamped.
  final DateTime? at;

  /// The line on the card. Floored at zero: a friend who went quiet publishes
  /// zeros, and a total that went backwards must not read as a debt.
  static int together({
    required int myTotal,
    required int myStartTotal,
    required int theirTotal,
    required int theirStartTotal,
  }) {
    final int n = (theirTotal - theirStartTotal) + (myTotal - myStartTotal);
    return n < 0 ? 0 : n;
  }

  factory FriendMeta.fromDoc(DocumentSnapshot<Map<String, Object?>> doc) {
    final Map<String, Object?> data = doc.data() ?? <String, Object?>{};
    final Object? mine = data['myStartTotal'];
    final Object? theirs = data['theirStartTotal'];
    final Object? at = data['at'];
    return FriendMeta(
      myStartTotal: mine is num ? mine.toInt() : 0,
      theirStartTotal: theirs is num ? theirs.toInt() : 0,
      at: at is Timestamp ? at.toDate() : null,
    );
  }

  /// The document as written; the server stamps `at`.
  Map<String, Object?> toMap() => <String, Object?>{
    'myStartTotal': myStartTotal,
    'theirStartTotal': theirStartTotal,
    'at': FieldValue.serverTimestamp(),
  };
}

/// What a person's friends can see of their prayers: `progress/{uid}`.
///
/// Counters, today's tally and the face beside them, nothing else. No prayer
/// times, no prayer-mat photos, no location — the document is a scoreboard,
/// not a diary. The owner's phone publishes it; friends read it.
///
/// The profile picture is the one thing here that is not a number, and it is
/// on this document for the same reason the name is: `users/{uid}` is private,
/// so a friend has no other way to see it.
@immutable
class FriendProgress {
  const FriendProgress({
    required this.uid,
    required this.name,
    required this.code,
    this.streak = 0,
    this.longestStreak = 0,
    this.totalPrayers = 0,
    this.totalTahajjud = 0,
    this.todayCompleted = 0,
    this.todayDate = '',
    this.lastCompletedDate,
    this.photo,
    this.updatedAt,
    this.quiet = false,
    this.milestone,
    this.ramadan,
  });

  /// The ceilings the security rules put on a published scoreboard.
  ///
  /// A scoreboard is self-reported by design, but self-reported is not the
  /// same as unbounded: without a ceiling a raw SDK can publish a streak of
  /// nine quintillion onto every friend's screen. 40000 is roughly a hundred
  /// years of days and 200000 is five prayers across the same span — figures
  /// no worshipper reaches. They live here because the publisher clamps to
  /// exactly them: a refused publish is silent, so an honest phone must never
  /// write a value the rules would reject.
  static const int maxStreak = 40000;
  static const int maxTotalPrayers = 200000;
  static const int maxTotalTahajjud = 40000;

  /// The longest a published picture may be, in base64 characters.
  ///
  /// Held at 64000 rather than lowered to the size of the small copy the
  /// editor now writes, because the rules cannot tell a new publish from an
  /// old document: a picture stored under the previous build is already out
  /// there at up to this length, and tightening the ceiling would freeze
  /// those scoreboards the next time their owner prayed.
  static const int maxPhotoChars = 64000;

  /// The shape the rules insist a day id has: "2026-09-14".
  static final RegExp dayIdPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  final String uid;
  final String name;
  final String code;

  /// The streak as last written by the owner's phone — see [streakToday] for
  /// the reading a friend should actually be shown.
  final int streak;
  final int longestStreak;
  final int totalPrayers;
  final int totalTahajjud;

  /// How many of the five were confirmed on [todayDate].
  final int todayCompleted;

  /// "2026-09-14" — the day [todayCompleted] counts. A friend in another
  /// timezone may be a day ahead or behind, which is why it is written down
  /// rather than assumed.
  final String todayDate;

  /// "2026-09-13" — the last day all five prayers were confirmed.
  final String? lastCompletedDate;

  /// Their profile picture as a base64 JPEG, or null for none.
  ///
  /// A copy, like the name: the user document it is written on is private, so
  /// this is the only place a friend can read it from. Bounded by
  /// [maxPhotoChars] in the rules — not by `Avatar.maxChars`, which is the
  /// ceiling on the owner's own full-size copy and is three times larger.
  /// The two parted company when the crop editor shipped, and this is the one
  /// `photoWithinCeiling` actually enforces. Never trusted on the way in
  /// either — a string that does not decode ends at their initials.
  final String? photo;

  /// Server time of the last publish. Null before the first one lands.
  final DateTime? updatedAt;

  /// Whether the owner has gone quiet: every number on this document is a
  /// zero they published on purpose, and a friend's screen shows "Quiet for
  /// now" in place of all of them.
  ///
  /// The zeros are the point. Hiding the numbers on the reading side alone
  /// would leave them sitting in the document for any client to fetch, and
  /// "quiet" has to mean the server holds nothing worth fetching.
  final bool quiet;

  /// Their latest milestone, shown to friends for a week after it was
  /// reached. Null when there is none, when it is older than a week the
  /// reading side should check with [Milestone.isFresh], and always when
  /// [quiet].
  final Milestone? milestone;

  /// How their Ramadan is going. Present only during Ramadan, and never when
  /// [quiet].
  final RamadanShare? ramadan;

  String get initials => _initialsOf(name);

  /// This scoreboard with every number withheld: what a person who has gone
  /// quiet publishes in place of it.
  ///
  /// Name, code and picture stay — they say who this is, not how they are
  /// doing — and so does today's date, because the rules require one. The
  /// milestone and the Ramadan line go with the numbers: each is a number in
  /// a different coat.
  FriendProgress silenced() => FriendProgress(
    uid: uid,
    name: name,
    code: code,
    todayDate: todayDate,
    photo: photo,
    updatedAt: updatedAt,
    quiet: true,
  );

  /// The streak as it stands on [now], not as it was last written.
  ///
  /// Same rule as `UserStats.streakOn`: the chain is alive only if the last
  /// finished day was today or yesterday. A friend who stopped opening the
  /// app must not go on showing a streak they no longer have.
  int streakOn(DateTime now) {
    final String? last = lastCompletedDate;
    if (last == null || streak == 0) return 0;
    final String today = Fmt.dayId(now);
    final String yesterday = Fmt.dayId(now.subtract(const Duration(days: 1)));
    return last == today || last == yesterday ? streak : 0;
  }

  int get streakToday => streakOn(DateTime.now());

  /// Whether at least one prayer has been confirmed on [now]'s date.
  bool prayedOn(DateTime now) =>
      todayDate == Fmt.dayId(now) && todayCompleted > 0;

  bool get prayedToday => prayedOn(DateTime.now());

  factory FriendProgress.fromDoc(DocumentSnapshot<Map<String, Object?>> doc) {
    final Map<String, Object?> data = doc.data() ?? <String, Object?>{};
    return FriendProgress(
      uid: doc.id,
      name: FriendName.clean(data['name'] as String?),
      code: data['code'] as String? ?? '',
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      longestStreak: (data['longestStreak'] as num?)?.toInt() ?? 0,
      totalPrayers: (data['totalPrayers'] as num?)?.toInt() ?? 0,
      totalTahajjud: (data['totalTahajjud'] as num?)?.toInt() ?? 0,
      todayCompleted: (data['todayCompleted'] as num?)?.toInt() ?? 0,
      todayDate: data['todayDate'] as String? ?? '',
      lastCompletedDate: data['lastCompletedDate'] as String?,
      // Tested rather than cast: this document belongs to someone else, and
      // anything but a string here would throw inside their progress listener.
      photo: data['photo'] is String ? data['photo'] as String : null,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      // The three newer keys, each tested the same way: absent on a document
      // from an older build, and never worth a throw on somebody else's data.
      quiet: data['quiet'] == true,
      milestone: Milestone.fromMap(data['milestone']),
      ramadan: RamadanShare.fromMap(data['ramadan']),
    );
  }

  /// The fields a friend would see. [updatedAt] is left out: the repository
  /// stamps it with the server clock on every publish, and the publisher
  /// compares two of these maps to decide whether anything visible changed.
  Map<String, Object?> toMap() => <String, Object?>{
    'name': name,
    'code': code,
    'streak': streak,
    'longestStreak': longestStreak,
    'totalPrayers': totalPrayers,
    'totalTahajjud': totalTahajjud,
    'todayCompleted': todayCompleted,
    'todayDate': todayDate,
    'lastCompletedDate': lastCompletedDate,
    // Always present, even as a null. The publisher decides whether to write
    // by comparing two of these maps, so a key that comes and goes would make
    // a picture that was removed look like no change at all.
    'photo': photo,
    // Always written, so a friend's phone reads an explicit false rather
    // than inferring one from an absent key.
    'quiet': quiet,
    // Present only while there is one. The document is replaced wholesale on
    // every publish, so leaving the key out is how a stale milestone or the
    // end of Ramadan comes off the scoreboard.
    if (milestone != null) 'milestone': milestone!.toMap(),
    if (ramadan != null) 'ramadan': ramadan!.toMap(),
  };
}

/// Why adding a friend by code did not go through.
enum FriendAddError {
  invalidCode,
  notFound,
  yourself,
  already,
  notSignedIn,
  guest,

  /// The rules would not have it. In practice that means the other person
  /// removed you: removing a friend blocks them, and only they can lift it.
  refused;

  /// What to tell the person, in the app's voice.
  String get message => switch (this) {
    FriendAddError.invalidCode =>
      'A friend code is six letters and numbers, like ABC-234.',
    FriendAddError.notFound =>
      'No one has that code. Check it with your friend and try again.',
    FriendAddError.yourself => 'That is your own code.',
    FriendAddError.already => 'You are already friends.',
    FriendAddError.notSignedIn => 'Sign in to add friends.',
    FriendAddError.guest =>
      'Friends need a full account. Add an email and password from your '
          'profile and keep your streak.',
    FriendAddError.refused =>
      'Layla Pro could not add that friend. If you were friends before, they '
          'will need to add you back.',
  };
}

class FriendAddException implements Exception {
  const FriendAddException(this.error);

  final FriendAddError error;

  String get message => error.message;

  @override
  String toString() => message;
}
