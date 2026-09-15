import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/prefs_service.dart';

/// The names a person has bookmarked, by their index in [NamesOfAllah.all].
final NotifierProvider<NamesSavedStore, Set<int>> savedNamesProvider =
    NotifierProvider<NamesSavedStore, Set<int>>(NamesSavedStore.new);

/// The names a person has shown they know, in the quiz — also by index.
final NotifierProvider<NamesKnownStore, Set<int>> knownNamesProvider =
    NotifierProvider<NamesKnownStore, Set<int>>(NamesKnownStore.new);

class _IndexSetStore extends Notifier<Set<int>> {
  _IndexSetStore(this._key);

  final String _key;

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  Set<int> build() => <int>{
    for (final String s in _prefs.getStringList(_key) ?? const <String>[])
      if (int.tryParse(s) case final int i) i,
  };

  Future<void> toggle(int index) async {
    final Set<int> next = <int>{...state};
    if (!next.remove(index)) next.add(index);
    state = next;
    await _write();
  }

  Future<void> add(int index) async {
    if (state.contains(index)) return;
    state = <int>{...state, index};
    await _write();
  }

  Future<void> _write() =>
      _prefs.setStringList(_key, <String>[for (final int i in state) '$i']);
}

class NamesSavedStore extends _IndexSetStore {
  NamesSavedStore() : super('names_saved');
}

class NamesKnownStore extends _IndexSetStore {
  NamesKnownStore() : super('names_known');
}
