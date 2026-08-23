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
  missed('missed');

  const PrayerStatus(this.key);

  final String key;

  bool get countsForStreak => this == PrayerStatus.completed;

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
  });

  final String dateId;
  final Map<PrayerId, PrayerRecord> records;
  final bool tahajjudPrayed;
  final DateTime? tahajjudAt;

  PrayerRecord recordFor(PrayerId id) =>
      records[id] ?? const PrayerRecord();

  int get completedCount => PrayerId.obligatory
      .where((PrayerId id) => recordFor(id).isCompleted)
      .length;

  bool get isComplete => completedCount == PrayerId.obligatory.length;

  /// The prayer currently stuck at Step 2, if any — the router uses this to
  /// send the user back to the confirmation screen.
  PrayerId? get awaitingProof {
    for (final PrayerId id in PrayerId.obligatory) {
      if (recordFor(id).needsProof) return id;
    }
    return null;
  }

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
    );
  }
}

/// A rolling window of days for the streak calendar.
@immutable
class StreakHistory {
  const StreakHistory({required this.days});

  /// Keyed by "yyyy-MM-dd".
  final Map<String, PrayerDay> days;

  PrayerDay dayFor(String dateId) => days[dateId] ?? PrayerDay.empty(dateId);

  int get perfectDays =>
      days.values.where((PrayerDay d) => d.isComplete).length;

  int get totalConfirmed =>
      days.values.fold(0, (int sum, PrayerDay d) => sum + d.completedCount);

  int get tahajjudNights =>
      days.values.where((PrayerDay d) => d.tahajjudPrayed).length;
}
