import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/formatters.dart';

/// Which masjid somebody is going to this Friday: `jumuah/{uid}`.
///
/// The one place in Friends where typed words travel from one person to
/// another, which is why the name is capped hard at forty characters and
/// why nothing else on the document is text. Written by the owner, read by
/// their friends, and shown only while [date] is the coming Friday — a
/// masjid named three weeks ago says nothing about this week.
@immutable
class Jumuah {
  const Jumuah({required this.masjid, required this.date, this.updatedAt});

  /// The most characters a masjid name may carry; the rules refuse more.
  static const int maxLength = 40;

  final String masjid;

  /// "2026-09-18" — the Friday this is for.
  final String date;

  /// Server time of the last write. Null for the instant before it lands.
  final DateTime? updatedAt;

  /// The Friday a plan made on [today] is for: today when today is Friday,
  /// otherwise the next one. Whole calendar days through the `DateTime`
  /// constructor, which normalises an overflowed day of the month and does
  /// not lose an hour to daylight saving the way adding a `Duration` can.
  static String comingFridayId(DateTime today) {
    final int ahead = (DateTime.friday - today.weekday) % 7;
    return Fmt.dayId(DateTime(today.year, today.month, today.day + ahead));
  }

  /// Whether this plan is for the Friday that [today] is heading towards.
  bool isFor(DateTime today) => date == comingFridayId(today);

  /// [name] trimmed and cut to [maxLength] code points, empty when it was
  /// blank. Cut by rune rather than by UTF-16 unit, as `FriendName.clean` is,
  /// so a name ending in a character outside the basic plane is not split in
  /// half on its way to Firestore.
  static String clean(String name) {
    final String trimmed = name.trim();
    final List<int> runes = trimmed.runes.toList(growable: false);
    if (runes.length <= maxLength) return trimmed;
    return String.fromCharCodes(runes.take(maxLength));
  }

  /// The stored document read back, or null when it is not one this app
  /// wrote. Tested rather than cast: it is somebody else's document.
  static Jumuah? fromDoc(DocumentSnapshot<Map<String, Object?>> doc) {
    final Map<String, Object?> data = doc.data() ?? <String, Object?>{};
    final Object? masjid = data['masjid'];
    final Object? date = data['date'];
    final Object? updatedAt = data['updatedAt'];
    if (masjid is! String || masjid.trim().isEmpty) return null;
    if (date is! String || Fmt.parseDayId(date) == null) return null;
    return Jumuah(
      masjid: clean(masjid),
      date: date,
      updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : null,
    );
  }

  /// The document as written; the server stamps `updatedAt`.
  Map<String, Object?> toMap() => <String, Object?>{
    'masjid': masjid,
    'date': date,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  @override
  bool operator ==(Object other) =>
      other is Jumuah &&
      other.masjid == masjid &&
      other.date == date &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(masjid, date, updatedAt);
}
