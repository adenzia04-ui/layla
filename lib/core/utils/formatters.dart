import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart';

/// All date/time strings in Noor are produced here, so the app never mixes
/// 12h and 24h or two different date styles on the same screen.
abstract final class Fmt {
  static final DateFormat _clock12 = DateFormat('h:mm');
  static final DateFormat _clock24 = DateFormat('HH:mm');
  static final DateFormat _time12 = DateFormat('h:mm a');
  static final DateFormat _dayDate = DateFormat('EEEE, d MMMM');
  static final DateFormat _shortDate = DateFormat('d MMM');
  static final DateFormat _docId = DateFormat('yyyy-MM-dd');

  /// "6:35" — the numerals only; pair with [meridiem] for the small suffix.
  static String clock(DateTime t, {bool use24h = false}) =>
      use24h ? _clock24.format(t) : _clock12.format(t);

  /// "PM"
  static String meridiem(DateTime t) => DateFormat('a').format(t);

  /// ":07" — the seconds, rendered small beside the hero clock so a live
  /// screen visibly ticks instead of looking frozen for a whole minute.
  static String seconds(DateTime t) => ':${DateFormat('ss').format(t)}';

  /// "7:12 PM"
  static String time(DateTime t, {bool use24h = false}) =>
      use24h ? _clock24.format(t) : _time12.format(t);

  /// "Tuesday, 23 June"
  static String dayDate(DateTime t) => _dayDate.format(t);

  /// "23 Jun"
  static String shortDate(DateTime t) => _shortDate.format(t);

  /// "2026-08-20" — the Firestore document id for a prayer day.
  static String dayId(DateTime t) => _docId.format(t);

  /// "12 Safar 1448 AH"
  static String hijri(DateTime t) {
    final HijriCalendar h = HijriCalendar.fromDate(t);
    return '${h.hDay} ${h.longMonthName} ${h.hYear} AH';
  }

  /// Countdown in the reference's voice, now ticking: "1hr 10min",
  /// "32min 04s", "48s".
  ///
  /// Seconds are shown below the hour mark, where they are the part that
  /// actually moves. Past an hour they would only add width to a number that
  /// changes once a minute anyway.
  static String countdown(Duration d) {
    if (d.isNegative) return 'now';
    final int hours = d.inHours;
    final int minutes = d.inMinutes.remainder(60);
    final int seconds = d.inSeconds.remainder(60);

    if (hours > 0) {
      return minutes == 0 ? '${hours}hr' : '${hours}hr ${minutes}min';
    }
    if (minutes > 0) {
      return '${minutes}min ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }

  /// Long form for the focus screen: "28:04".
  static String mmss(Duration d) {
    if (d.isNegative) return '00:00';
    final String m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final String s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  /// "2h ago", "3d ago" — story feed timestamps.
  static String relative(DateTime t) {
    final Duration diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return shortDate(t);
  }

  /// Strips the time so two DateTimes on the same day compare equal.
  static DateTime dayStart(DateTime t) => DateTime(t.year, t.month, t.day);
}
