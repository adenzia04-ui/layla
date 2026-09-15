import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/prefs_service.dart';

/// The duas someone has starred, by the book's own number.
///
/// Keyed by number rather than by position, so a star survives the list being
/// reordered — which it is, since starred duas rise to the top.
final NotifierProvider<StarredDuas, Set<int>> starredDuasProvider =
    NotifierProvider<StarredDuas, Set<int>>(StarredDuas.new);

class StarredDuas extends Notifier<Set<int>> {
  @override
  Set<int> build() => ref.watch(prefsProvider).starredDuas;

  bool isStarred(int number) => state.contains(number);

  void toggle(int number) {
    // A new set, not a mutation: Riverpod compares by identity, so changing
    // the existing one in place would leave the UI showing the old stars.
    final Set<int> next = <int>{...state};
    if (!next.remove(number)) next.add(number);
    state = next;
    ref.read(prefsProvider).setStarredDuas(next);
  }
}

/// Starred first, each group keeping the book's order.
///
/// A stable partition rather than a sort: sorting on a boolean leaves the
/// order within each group at the mercy of the sort's stability, and the
/// book's sequence is meaningful.
List<T> starredFirst<T>(
  List<T> items,
  Set<int> starred,
  int Function(T) number,
) => <T>[
  ...items.where((T e) => starred.contains(number(e))),
  ...items.where((T e) => !starred.contains(number(e))),
];
