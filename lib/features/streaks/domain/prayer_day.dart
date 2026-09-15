import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../prayer_times/domain/prayer.dart';

/// The lifecycle of a single prayer. A prayer is only ever `completed` once a
/// prayer-mat photo has been uploaded successfully — see
/// `docs/PRAYER_LOCK_LIMITATIONS.md`.
enum PrayerStatus {
  /// Its time has not arrived, or it has and nothing has been done yet.
  pending('pending'),

  /// Step 1 done ("I Have Prayed"), Step 2 outstanding. **Not** completed.
  awaitingProof('awaiting_proof'),

  /// Both steps done — this is the only status that counts toward a streak.
  completed('completed'),

  /// The window closed without confirmation.
  missed('missed'),

  /// The prayer pause covers this day, so this prayer was neither prayed nor
  /// missed — and it is not owed.
  ///
  /// A woman does not pray during menstruation, and unlike the fast these
  /// prayers are never made up afterwards: Aisha (may Allah be pleased with
  /// her), asked why the fast is made up and the prayer is not, answered that
  /// they were commanded to make up the one and not the other (Sahih Muslim
  /// 335). So this is deliberately not a shade of [missed]. Nothing counts it
  /// against her, nothing asks for it back, and nothing may ever present it as
  /// a debt.
  excused('excused');

  const PrayerStatus(this.key);

  final String key;

  bool get countsForStreak => this == PrayerStatus.completed;

  /// Whether this prayer is one the app must stop asking about.
  ///
  /// Completed and missed both settle a prayer; so does the pause, and for the
  /// same practical purpose — there is nothing left to prompt for. Written
  /// once here so the lock, the reminders and the home choices cannot drift
  /// apart on which states are finished.
  bool get isSettled =>
      this == PrayerStatus.completed ||
      this == PrayerStatus.missed ||
      this == PrayerStatus.excused;

  static PrayerStatus fromKey(String? key) => PrayerStatus.values.firstWhere(
    (PrayerStatus s) => s.key == key,
    orElse: () => PrayerStatus.pending,
  );
}

@immutable
class PrayerRecord {
  const PrayerRecord({
    this.status = PrayerStatus.pending,
    this.scheduledAt,
    this.confirmedAt,
    this.proofPath,
    this.startedAt,
  });

  final PrayerStatus status;
  final DateTime? scheduledAt;

  /// When Step 2 completed. Null unless [status] is `completed`.
  final DateTime? confirmedAt;

  /// Storage path of the prayer-mat photo — never a public URL.
  final String? proofPath;

  /// When Step 1 was pressed.
  final DateTime? startedAt;

  bool get isCompleted => status == PrayerStatus.completed;
  bool get needsProof => status == PrayerStatus.awaitingProof;

  /// Covered by the prayer pause. Never "owed" — see [PrayerStatus.excused].
  bool get isExcused => status == PrayerStatus.excused;

  factory PrayerRecord.fromMap(Map<String, Object?>? map) {
    if (map == null) return const PrayerRecord();
    return PrayerRecord(
      status: PrayerStatus.fromKey(map['status'] as String?),
      scheduledAt: (map['scheduledAt'] as Timestamp?)?.toDate(),
      confirmedAt: (map['confirmedAt'] as Timestamp?)?.toDate(),
      startedAt: (map['startedAt'] as Timestamp?)?.toDate(),
      proofPath: map['proofPath'] as String?,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    'status': status.key,
    if (scheduledAt != null) 'scheduledAt': Timestamp.fromDate(scheduledAt!),
    if (confirmedAt != null) 'confirmedAt': Timestamp.fromDate(confirmedAt!),
    if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),
    if (proofPath != null) 'proofPath': proofPath,
  };
}

/// One document per local day: `users/{uid}/prayer_days/{yyyy-MM-dd}`.
@immutable
class PrayerDay {
  const PrayerDay({
    required this.dateId,
    this.records = const <PrayerId, PrayerRecord>{},
    this.tahajjudPrayed = false,
    this.tahajjudAt,
    this.excused = false,
  });

  final String dateId;
  final Map<PrayerId, PrayerRecord> records;
  final bool tahajjudPrayed;
  final DateTime? tahajjudAt;

  /// Whether the prayer pause covers this day.
  ///
  /// Lives on the day document, which — like the user document the pause
  /// itself is stored on — only its owner can read. It is never published to
  /// `progress/{uid}`, which friends read, nor to the widget snapshot, which
  /// anybody who picks up the phone can see on the Lock Screen.
  final bool excused;

  PrayerRecord recordFor(PrayerId id) => records[id] ?? const PrayerRecord();

  int get completedCount => PrayerId.obligatory
      .where((PrayerId id) => recordFor(id).isCompleted)
      .length;

  /// Whether all five were confirmed. Never true on an excused day.
  ///
  /// There was nothing to complete on a day the pause covers, so calling one
  /// "complete" would be a claim about prayers that were never owed. It is
  /// also what stops the chain being advanced twice for a single day: an
  /// excused day has already carried `lastCompletedDate` forward by the time
  /// anything else looks at it — see `StreakStats.afterExcusedDay`.
  bool get isComplete =>
      !excused && completedCount == PrayerId.obligatory.length;

  /// Whether any prayer on this day was recorded as missed.
  ///
  /// Never true on an excused day. A missed prayer is one that was owed and
  /// not prayed, and on a paused day none of them were owed — the year view
  /// and the day sheet both read this to decide whether to mark a day red.
  bool get anyMissed =>
      !excused &&
      records.values.any((PrayerRecord r) => r.status == PrayerStatus.missed);

  /// The prayer currently stuck at Step 2, if any — the router uses this to
  /// send the user back to the confirmation screen.
  PrayerId? get awaitingProof {
    for (final PrayerId id in PrayerId.obligatory) {
      if (recordFor(id).needsProof) return id;
    }
    return null;
  }

  /// This day as the prayer pause will leave it once the catch-up has run.
  ///
  /// Two separate things say a day is paused, and they do not arrive together.
  /// The profile knows the moment the app opens; this document only says so
  /// after `CycleRepository.catchUp` has written it, which is a network round
  /// trip away and, offline, may not happen at all that session. In between,
  /// a day covered by the pause still reads as five prayers pending — so Home
  /// would print "0 of 5 confirmed", the exact line a day of missed prayers
  /// shows, and breathe a bead over a prayer that is not owed, both directly
  /// above the words "these prayers are not owed". That gap is not rare: it is
  /// every cold open from the second day of a pause onwards.
  ///
  /// This closes it by showing the answer the write is going to bring back.
  /// It matches `PrayerDayRepository.markExcused` exactly, including leaving a
  /// prayer that was confirmed before the pause began alone — otherwise the
  /// screen would change under her when the write landed.
  ///
  /// A day where all five were already confirmed is handed back untouched,
  /// because that is what `markExcused` does with one: `ExcusedDayWrite.decide`
  /// returns nothing for a finished day and writes neither the flag nor the
  /// records. Without that arm a pause begun in the evening — which is when
  /// most begin — would blank the count on a day she actually finished, five
  /// gold beads sitting above a panel saying nothing was owed.
  ///
  /// Display only, and deliberately not applied inside `todayPrayerDayProvider`:
  /// the friends scoreboard and the Lock Screen widget read that provider too,
  /// and neither may ever be handed a day carrying the pause. The caller opts
  /// in, and today the only caller is Home.
  PrayerDay asExcused() => isComplete
      ? this
      : PrayerDay(
          dateId: dateId,
          tahajjudPrayed: tahajjudPrayed,
          tahajjudAt: tahajjudAt,
          excused: true,
          records: <PrayerId, PrayerRecord>{
            ...records,
            for (final PrayerId id in PrayerId.obligatory)
              if (!recordFor(id).isCompleted)
                id: const PrayerRecord(status: PrayerStatus.excused),
          },
        );

  factory PrayerDay.empty(String dateId) => PrayerDay(dateId: dateId);

  factory PrayerDay.fromDoc(DocumentSnapshot<Map<String, Object?>> doc) {
    final Map<String, Object?> data = doc.data() ?? <String, Object?>{};
    final Map<String, Object?> prayers =
        (data['prayers'] as Map<String, Object?>?) ?? <String, Object?>{};
    final Map<String, Object?> tahajjud =
        (data['tahajjud'] as Map<String, Object?>?) ?? <String, Object?>{};

    return PrayerDay(
      dateId: doc.id,
      records: <PrayerId, PrayerRecord>{
        for (final PrayerId id in PrayerId.obligatory)
          id: PrayerRecord.fromMap(prayers[id.key] as Map<String, Object?>?),
      },
      tahajjudPrayed: tahajjud['prayed'] as bool? ?? false,
      tahajjudAt: (tahajjud['at'] as Timestamp?)?.toDate(),
      // Tested rather than cast: this decides whether the app will mark
      // prayers missed and whether it keeps a streak, and a cast that threw
      // inside a snapshot listener would take the whole day stream with it.
      excused: data['excused'] == true,
    );
  }
}

/// One calendar year of days, for the year view.
@immutable
class StreakHistory {
  const StreakHistory({required this.year, required this.days});

  final int year;

  /// Keyed by "yyyy-MM-dd". Only days with a record are present.
  final Map<String, PrayerDay> days;

  PrayerDay dayFor(String dateId) => days[dateId] ?? PrayerDay.empty(dateId);

  int get perfectDays =>
      days.values.where((PrayerDay d) => d.isComplete).length;

  int get totalConfirmed =>
      days.values.fold(0, (int sum, PrayerDay d) => sum + d.completedCount);

  /// How many prayers were actually owed over the first [daysElapsed] days.
  ///
  /// Five a day, except on a day the prayer pause covers: there only the ones
  /// prayed before it began were owed, and the rest are not a shortfall and
  /// never become one — there is no qada for them (Sahih Muslim 335). This is
  /// the denominator of the year bar, and it is the difference between the
  /// truth and the app telling a woman who prayed everything she owed that she
  /// confirmed 84% of her year, every year, for as long as she uses it.
  int owedPrayers(int daysElapsed) {
    final int all = PrayerId.obligatory.length;
    int owed = daysElapsed * all;
    for (final PrayerDay d in days.values) {
      if (d.excused) owed -= all - d.completedCount;
    }
    return owed < 0 ? 0 : owed;
  }

  int get tahajjudNights =>
      days.values.where((PrayerDay d) => d.tahajjudPrayed).length;
}
