import 'package:flutter/foundation.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../core/utils/formatters.dart';
import 'friend.dart';

/// The Hijri facts the app acts on: whether it is Ramadan, and whether it is
/// Eid.
///
/// Read off `package:hijri`, the same calendar `Fmt.hijri` prints, so the
/// day the Ramadan card appears is the day the date line says Ramadan began.
/// Umm al-Qura is a calculation, not a sighting, and it can be a day out
/// from a given community's announcement; a day either side is the accepted
/// cost of needing no server and no setting.
abstract final class HijriDates {
  static const int ramadan = 9;
  static const int shawwal = 10;
  static const int dhulHijjah = 12;

  /// The two Eids, as `eidTodayProvider` numbers them.
  static const int eidAlFitr = 1;
  static const int eidAlAdha = 2;

  static HijriCalendar of(DateTime day) => HijriCalendar.fromDate(day);

  static int yearOf(DateTime day) => of(day).hYear;

  static bool isRamadan(DateTime day) => of(day).hMonth == ramadan;

  /// 1 on 1 Shawwal, 2 on 10 Dhul-Hijjah, null on every other day.
  static int? eidOn(DateTime day) {
    final HijriCalendar h = of(day);
    if (h.hMonth == shawwal && h.hDay == 1) return eidAlFitr;
    if (h.hMonth == dhulHijjah && h.hDay == 10) return eidAlAdha;
    return null;
  }

  /// "1448-1" — the key under `users/{uid}.eidSent` for the Eid [eid] of the
  /// Hijri year [day] falls in. One greeting per Eid per year, and this is
  /// how a relaunch on the same day knows it has already gone out.
  static String eidKey(DateTime day, int eid) => '${yearOf(day)}-$eid';
}

/// Somebody's own Ramadan, on their private document: `users/{uid}.ramadan`.
///
/// A count of fasts and the last day each of the two things was ticked. The
/// scoreboard never carries this map; it carries [share], which is derived
/// from it for today and only during Ramadan. Keyed to the Hijri year so that
/// last year's thirty fasts do not open this year at thirty.
@immutable
class RamadanRecord {
  const RamadanRecord({
    required this.year,
    this.fasts = 0,
    this.fastedOn,
    this.taraweehOn,
  });

  /// The Hijri year this record counts.
  final int year;

  /// Fasts kept this Ramadan, 0 to [RamadanShare.maxFasts].
  final int fasts;

  /// "2027-02-20" — the last day "I fasted today" was ticked, or null.
  final String? fastedOn;

  /// "2027-02-20" — the last night "Taraweeh tonight" was ticked, or null.
  final String? taraweehOn;

  bool fastedOnDay(String dayId) => fastedOn == dayId;

  bool taraweehOnDay(String dayId) => taraweehOn == dayId;

  /// This record if it is for [year], otherwise a fresh one for it — a stored
  /// record from an earlier Ramadan is history, not a starting count.
  RamadanRecord forYear(int year) =>
      this.year == year ? this : RamadanRecord(year: year);

  /// Today's fast ticked or unticked. Ticking a day already ticked changes
  /// nothing, so a double tap is one fast; unticking takes that fast back.
  RamadanRecord withFasted(String today, bool fasted) {
    if (fasted == fastedOnDay(today)) return this;
    return RamadanRecord(
      year: year,
      fasts: (fasts + (fasted ? 1 : -1)).clamp(0, RamadanShare.maxFasts),
      fastedOn: fasted ? today : null,
      taraweehOn: taraweehOn,
    );
  }

  /// Tonight's Taraweeh ticked or unticked. Nothing is counted; it is a
  /// yes-or-no for the night.
  RamadanRecord withTaraweeh(String today, bool prayed) {
    if (prayed == taraweehOnDay(today)) return this;
    return RamadanRecord(
      year: year,
      fasts: fasts,
      fastedOn: fastedOn,
      taraweehOn: prayed ? today : null,
    );
  }

  /// What friends may see of this, for [today].
  RamadanShare share(String today) => RamadanShare(
    fasts: fasts.clamp(0, RamadanShare.maxFasts),
    fastingToday: fastedOnDay(today),
    taraweeh: taraweehOnDay(today),
    date: today,
  );

  /// The stored map read back, or null when it is not one this app wrote.
  /// Tested rather than cast, like everything else read off the profile: a
  /// throw here would take the whole profile stream with it.
  static RamadanRecord? fromMap(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? year = raw['year'];
    final Object? fasts = raw['fasts'];
    if (year is! num) return null;
    return RamadanRecord(
      year: year.toInt(),
      fasts: (fasts is num ? fasts.toInt() : 0).clamp(0, RamadanShare.maxFasts),
      fastedOn: _dayId(raw['fastedOn']),
      taraweehOn: _dayId(raw['taraweehOn']),
    );
  }

  static String? _dayId(Object? value) =>
      value is String && Fmt.parseDayId(value) != null ? value : null;

  Map<String, Object?> toMap() => <String, Object?>{
    'year': year,
    'fasts': fasts,
    'fastedOn': fastedOn,
    'taraweehOn': taraweehOn,
  };

  @override
  bool operator ==(Object other) =>
      other is RamadanRecord &&
      other.year == year &&
      other.fasts == fasts &&
      other.fastedOn == fastedOn &&
      other.taraweehOn == taraweehOn;

  @override
  int get hashCode => Object.hash(year, fasts, fastedOn, taraweehOn);

  @override
  String toString() =>
      'RamadanRecord($year: $fasts fasts, fasted $fastedOn, '
      'taraweeh $taraweehOn)';
}
