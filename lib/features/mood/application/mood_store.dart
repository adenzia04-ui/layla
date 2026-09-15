import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/prefs_service.dart';
import '../domain/mood_comfort.dart';

// Everything here stays on the phone. No account, no cloud, no analytics:
// what someone felt and what they wrote about it is theirs, and a feature
// that quietly sent it anywhere would betray the reason they opened it.

/// Ids of the passages someone has kept.
final NotifierProvider<SavedComforts, Set<String>> savedComfortsProvider =
    NotifierProvider<SavedComforts, Set<String>>(SavedComforts.new);

class SavedComforts extends Notifier<Set<String>> {
  static const String _key = 'mood_saved';

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  Set<String> build() => (_prefs.getStringList(_key) ?? <String>[]).toSet();

  bool contains(Comfort c) => state.contains(c.id);

  Future<void> toggle(Comfort c) async {
    final Set<String> next = Set<String>.from(state);
    if (!next.remove(c.id)) next.add(c.id);
    state = next;
    await _prefs.setStringList(_key, next.toList());
  }

  /// The saved passages, most recently saved first.
  List<Comfort> get comforts => <Comfort>[
    for (final String id in state.toList().reversed)
      if (MoodComfort.byId(id) case final Comfort c) c,
  ];
}

/// One line written after a deck: how it felt afterwards.
class JournalEntry {
  const JournalEntry({
    required this.at,
    required this.mood,
    required this.note,
    this.comfortId,
  });

  final DateTime at;
  final Mood mood;
  final String note;

  /// The card that was open when the line was written, if any.
  final String? comfortId;

  Map<String, Object?> toMap() => <String, Object?>{
    'at': at.toIso8601String(),
    'mood': mood.name,
    'note': note,
    if (comfortId != null) 'comfort': comfortId,
  };

  static JournalEntry? fromMap(Map<String, Object?> m) {
    final Mood? mood = Mood.byName(m['mood'] as String?);
    final DateTime? at = DateTime.tryParse(m['at'] as String? ?? '');
    if (mood == null || at == null) return null;
    return JournalEntry(
      at: at,
      mood: mood,
      note: m['note'] as String? ?? '',
      comfortId: m['comfort'] as String?,
    );
  }
}

/// The journal, newest first.
final NotifierProvider<MoodJournal, List<JournalEntry>> moodJournalProvider =
    NotifierProvider<MoodJournal, List<JournalEntry>>(MoodJournal.new);

class MoodJournal extends Notifier<List<JournalEntry>> {
  static const String _key = 'mood_journal';

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  List<JournalEntry> build() {
    final String? raw = _prefs.getString(_key);
    if (raw == null) return const <JournalEntry>[];
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List) return const <JournalEntry>[];
    return <JournalEntry>[
      for (final Object? e in decoded)
        if (e is Map<String, Object?>)
          if (JournalEntry.fromMap(e) case final JournalEntry entry) entry,
    ];
  }

  Future<void> add(JournalEntry entry) =>
      _write(<JournalEntry>[entry, ...state]);

  Future<void> remove(JournalEntry entry) =>
      _write(state.where((JournalEntry e) => e.at != entry.at).toList());

  Future<void> _write(List<JournalEntry> next) async {
    state = next;
    await _prefs.setString(
      _key,
      jsonEncode(next.map((JournalEntry e) => e.toMap()).toList()),
    );
  }
}

/// A feeling, on a day: what was picked, kept for the month view.
class MoodPick {
  const MoodPick({required this.at, required this.mood});

  final DateTime at;
  final Mood mood;
}

/// The last ninety days of picks, newest first.
final NotifierProvider<MoodHistory, List<MoodPick>> moodHistoryProvider =
    NotifierProvider<MoodHistory, List<MoodPick>>(MoodHistory.new);

class MoodHistory extends Notifier<List<MoodPick>> {
  static const String _key = 'mood_picks';
  static const int _keepDays = 90;

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  List<MoodPick> build() {
    final DateTime cutoff = DateTime.now().subtract(
      const Duration(days: _keepDays),
    );
    return <MoodPick>[
      for (final String line in _prefs.getStringList(_key) ?? <String>[])
        if (line.split('|') case [final String at, final String name])
          if (DateTime.tryParse(at) case final DateTime t
              when t.isAfter(cutoff))
            if (Mood.byName(name) case final Mood mood)
              MoodPick(at: t, mood: mood),
    ];
  }

  /// Records a pick. One entry per mood per day is enough.
  Future<void> record(Mood mood) async {
    final DateTime now = DateTime.now();
    final bool already = state.any(
      (MoodPick p) =>
          p.mood == mood &&
          p.at.year == now.year &&
          p.at.month == now.month &&
          p.at.day == now.day,
    );
    if (already) return;
    final List<MoodPick> next = <MoodPick>[
      MoodPick(at: now, mood: mood),
      ...state,
    ];
    state = next;
    await _prefs.setStringList(
      _key,
      next
          .map((MoodPick p) => '${p.at.toIso8601String()}|${p.mood.name}')
          .toList(),
    );
  }

  /// The moods picked on a given day.
  List<Mood> on(DateTime day) => <Mood>[
    for (final MoodPick p in state)
      if (p.at.year == day.year &&
          p.at.month == day.month &&
          p.at.day == day.day)
        p.mood,
  ];
}
