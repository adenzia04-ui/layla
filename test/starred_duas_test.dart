import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/services/prefs_service.dart';
import 'package:noor/features/dua/application/starred_duas.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, SharedPreferences)> boot([
    Map<String, Object> seed = const <String, Object>{},
  ]) async {
    SharedPreferences.setMockInitialValues(seed);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        prefsProvider.overrideWithValue(PrefsService(prefs)),
      ],
    );
    addTearDown(c.dispose);
    return (c, prefs);
  }

  test('starring is a toggle and it survives a restart', () async {
    final (ProviderContainer c, SharedPreferences prefs) = await boot();
    expect(c.read(starredDuasProvider), isEmpty);

    c.read(starredDuasProvider.notifier).toggle(76);
    expect(c.read(starredDuasProvider), <int>{76});

    c.read(starredDuasProvider.notifier).toggle(76);
    expect(c.read(starredDuasProvider), isEmpty, reason: 'a second tap undoes');

    c.read(starredDuasProvider.notifier).toggle(76);
    c.read(starredDuasProvider.notifier).toggle(12);
    // toggle() writes without awaiting — deliberately, so the star flips the
    // instant it is tapped. Let the write land before reading it back.
    await Future<void>.delayed(Duration.zero);
    expect(
      prefs.getStringList('starred_duas'),
      containsAll(<String>['76', '12']),
    );

    // A fresh container over the same storage, as a cold launch would be.
    final ProviderContainer again = ProviderContainer(
      overrides: <Override>[
        prefsProvider.overrideWithValue(PrefsService(prefs)),
      ],
    );
    addTearDown(again.dispose);
    expect(again.read(starredDuasProvider), <int>{76, 12});
  });

  test(
    'starred rise to the top, and the book order holds within each group',
    () {
      const List<int> book = <int>[27, 28, 29, 30, 31];
      expect(starredFirst(book, <int>{29, 31}, (int n) => n), <int>[
        29,
        31,
        27,
        28,
        30,
      ], reason: 'starred first, each group still in the book’s sequence');
    },
  );

  test('no stars leaves the order exactly as the book has it', () {
    const List<int> book = <int>[27, 28, 29];
    expect(starredFirst(book, <int>{}, (int n) => n), book);
  });

  test('a star on a dua that is not in this section changes nothing', () {
    const List<int> book = <int>[27, 28];
    expect(starredFirst(book, <int>{99}, (int n) => n), book);
  });

  test('a corrupt stored value costs one star, not the list', () async {
    final (ProviderContainer c, _) = await boot(<String, Object>{
      'starred_duas': <String>['12', 'not-a-number', '76'],
    });
    expect(c.read(starredDuasProvider), <int>{
      12,
      76,
    }, reason: 'the unparseable entry is dropped, the rest survive');
  });
}
