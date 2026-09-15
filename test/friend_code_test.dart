import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/utils/formatters.dart';
import 'package:noor/features/friends/domain/friend.dart';

/// The code is read aloud and typed by hand, so the rules for what it may
/// contain and how typed input is cleaned are the part worth pinning down.
void main() {
  group('FriendCode.generate', () {
    test('is six characters, every one from the alphabet', () {
      final math.Random random = math.Random(7);
      for (int i = 0; i < 500; i++) {
        final String code = FriendCode.generate(random);
        expect(code.length, 6);
        expect(FriendCode.isValid(code), isTrue, reason: code);
        for (final String ch in code.split('')) {
          expect(FriendCode.alphabet.contains(ch), isTrue, reason: ch);
        }
      }
    });

    test('never contains the four look-alikes', () {
      expect(FriendCode.alphabet.contains('0'), isFalse);
      expect(FriendCode.alphabet.contains('O'), isFalse);
      expect(FriendCode.alphabet.contains('1'), isFalse);
      expect(FriendCode.alphabet.contains('I'), isFalse);
      expect(FriendCode.alphabet.length, 32);
    });

    test('is reproducible from a seed, so tests can pin one down', () {
      expect(
        FriendCode.generate(math.Random(42)),
        FriendCode.generate(math.Random(42)),
      );
    });
  });

  group('FriendCode.normalize', () {
    test('uppercases and drops the hyphen', () {
      expect(FriendCode.normalize('abc-234'), 'ABC234');
    });

    test('strips the look-alikes rather than guessing what was meant', () {
      expect(FriendCode.normalize('O0I1abc234'), 'ABC234');
      expect(FriendCode.normalize('a0b1c2'), 'ABC2');
    });

    test('ignores whitespace and punctuation from a paste', () {
      expect(FriendCode.normalize('  ab c-2 34 '), 'ABC234');
      expect(FriendCode.normalize('ABC.234!'), 'ABC234');
    });

    test('cuts at six', () {
      expect(FriendCode.normalize('ABC234XYZ'), 'ABC234');
    });

    test('leaves nothing of nothing', () {
      expect(FriendCode.normalize(''), '');
      expect(FriendCode.normalize('---'), '');
    });
  });

  group('FriendCode.display', () {
    test('puts the hyphen after the third character', () {
      expect(FriendCode.display('ABC234'), 'ABC-234');
    });

    test('cleans before it formats, so a typed code echoes back tidy', () {
      expect(FriendCode.display('abc-234'), 'ABC-234');
      expect(FriendCode.display('abc 234'), 'ABC-234');
    });

    test('adds no hyphen to a code still being typed', () {
      expect(FriendCode.display('AB'), 'AB');
      expect(FriendCode.display('ABC'), 'ABC');
      expect(FriendCode.display('ABC2'), 'ABC-2');
      expect(FriendCode.display(''), '');
    });
  });

  group('FriendCode.isValid', () {
    test('accepts six characters from the alphabet', () {
      expect(FriendCode.isValid('ABC234'), isTrue);
      expect(FriendCode.isValid('ZZZZZZ'), isTrue);
      expect(FriendCode.isValid('222222'), isTrue);
    });

    test('refuses the wrong length', () {
      expect(FriendCode.isValid('ABC23'), isFalse);
      expect(FriendCode.isValid('ABC2345'), isFalse);
      expect(FriendCode.isValid(''), isFalse);
    });

    test('refuses anything outside the alphabet, including the hyphen', () {
      expect(FriendCode.isValid('ABC-23'), isFalse);
      expect(FriendCode.isValid('abc234'), isFalse);
      expect(FriendCode.isValid('ABC0IO'), isFalse);
      expect(FriendCode.isValid('ABC 34'), isFalse);
    });
  });

  // The security rules refuse a name that is empty or longer than forty on
  // the code document, on both sides of a friendship and on the progress
  // document. A refusal there is invisible to the person it happens to, so
  // the bound is pinned down here rather than left to each call site.
  group('FriendName.clean', () {
    test('stands something in for a profile with no name yet', () {
      expect(FriendName.clean(null), FriendName.fallback);
      expect(FriendName.clean(''), FriendName.fallback);
      expect(FriendName.clean('   '), FriendName.fallback);
      expect(FriendName.clean('\n\t '), FriendName.fallback);
    });

    test('trims, and leaves an ordinary name as it is', () {
      expect(FriendName.clean('  Amira Khan  '), 'Amira Khan');
      expect(FriendName.clean('Amira'), 'Amira');
    });

    test('cuts at forty, and keeps a name of exactly forty', () {
      final String forty = 'a' * FriendName.maxLength;
      expect(FriendName.clean(forty), forty);
      expect(FriendName.clean('$forty and more').length, FriendName.maxLength);
    });

    test('cuts by character, never through half of one', () {
      // Each of these is one character and two UTF-16 units; `substring`
      // would leave an unpaired surrogate behind, which is not text
      // Firestore will take.
      final String long = '\u{1F31F}' * 45;
      final String cut = FriendName.clean(long);
      expect(cut.runes.length, FriendName.maxLength);
      expect(cut.codeUnits.length, FriendName.maxLength * 2);
      expect(cut.runes.every((int r) => r == 0x1F31F), isTrue);
    });

    test('every result is one the rules accept', () {
      const List<String?> inputs = <String?>[
        null,
        '',
        '   ',
        'Amira',
        'a very long name that runs well past the forty the rules allow',
      ];
      for (final String? input in inputs) {
        final int size = FriendName.clean(input).runes.length;
        expect(size, greaterThanOrEqualTo(1), reason: '$input');
        expect(size, lessThanOrEqualTo(FriendName.maxLength), reason: '$input');
      }
    });
  });

  group('FriendProgress.streakToday', () {
    final DateTime today = DateTime(2026, 9, 14, 21);
    String id(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    FriendProgress progress({int streak = 4, String? last}) => FriendProgress(
      uid: 'u1',
      name: 'Amira',
      code: 'ABC234',
      streak: streak,
      lastCompletedDate: last,
    );

    test('a day finished today keeps the streak', () {
      expect(progress(last: id(today)).streakOn(today), 4);
    });

    test('a day finished yesterday keeps it — today is still in progress', () {
      final DateTime yesterday = today.subtract(const Duration(days: 1));
      expect(progress(last: id(yesterday)).streakOn(today), 4);
    });

    test('anything older reads 0, whatever was last published', () {
      final DateTime twoDaysAgo = today.subtract(const Duration(days: 2));
      expect(
        progress(last: id(twoDaysAgo)).streakOn(today),
        0,
        reason: 'a friend who stopped opening the app must not keep a streak',
      );
      expect(
        progress(
          last: id(today.subtract(const Duration(days: 30))),
        ).streakOn(today),
        0,
      );
    });

    test('no finished day, or a stored zero, is no streak', () {
      expect(progress(last: null).streakOn(today), 0);
      expect(progress(streak: 0, last: id(today)).streakOn(today), 0);
    });

    test('survives a month boundary', () {
      expect(progress(last: '2026-08-31').streakOn(DateTime(2026, 9, 1, 9)), 4);
    });

    test('the getter reads against the real clock', () {
      final DateTime now = DateTime.now();
      expect(progress(last: id(now)).streakToday, 4);
      expect(
        progress(last: id(now.subtract(const Duration(days: 3)))).streakToday,
        0,
      );
    });
  });

  group('FriendProgress.prayedToday', () {
    final DateTime today = DateTime(2026, 9, 14, 21);

    test('needs a prayer confirmed under today\'s date', () {
      const FriendProgress none = FriendProgress(
        uid: 'u1',
        name: 'Amira',
        code: 'ABC234',
        todayDate: '2026-09-14',
      );
      expect(none.prayedOn(today), isFalse);

      const FriendProgress some = FriendProgress(
        uid: 'u1',
        name: 'Amira',
        code: 'ABC234',
        todayCompleted: 2,
        todayDate: '2026-09-14',
      );
      expect(some.prayedOn(today), isTrue);
    });

    test('yesterday\'s tally does not count as today', () {
      const FriendProgress stale = FriendProgress(
        uid: 'u1',
        name: 'Amira',
        code: 'ABC234',
        todayCompleted: 5,
        todayDate: '2026-09-13',
      );
      expect(stale.prayedOn(today), isFalse);
    });
  });

  // The rules refuse a scoreboard whose day ids are in any other shape, and
  // the publisher swallows a refusal — friends would simply see a scoreboard
  // frozen at its old values. So the shape this app writes is pinned against
  // the pattern the publisher checks before it sends anything.
  group('FriendProgress.dayIdPattern', () {
    test('takes the day id this app writes', () {
      expect(
        FriendProgress.dayIdPattern.hasMatch(Fmt.dayId(DateTime(2026, 9, 14))),
        isTrue,
      );
      expect(
        FriendProgress.dayIdPattern.hasMatch(Fmt.dayId(DateTime(2026, 1, 1))),
        isTrue,
        reason: 'single-digit months and days are padded, not shortened',
      );
    });

    test('refuses what an older build might have left behind', () {
      expect(FriendProgress.dayIdPattern.hasMatch(''), isFalse);
      expect(FriendProgress.dayIdPattern.hasMatch('2026-9-14'), isFalse);
      expect(FriendProgress.dayIdPattern.hasMatch('14/09/2026'), isFalse);
      expect(FriendProgress.dayIdPattern.hasMatch('2026-09-14T21:00'), isFalse);
    });
  });

  // Ceilings a real worshipper cannot reach, and the rules refuse anything
  // past them. Pinned so that lowering one here without lowering it in
  // firestore.rules cannot pass unnoticed.
  group('FriendProgress ceilings', () {
    test('hold a century of days and five prayers across it', () {
      const int centuryOfDays = 100 * 365;
      expect(FriendProgress.maxStreak, greaterThan(centuryOfDays));
      expect(FriendProgress.maxTotalTahajjud, greaterThan(centuryOfDays));
      expect(FriendProgress.maxTotalPrayers, greaterThan(centuryOfDays * 5));
    });
  });

  group('initials', () {
    test('match the app user rule', () {
      expect(
        const Friend(uid: 'u', name: 'Amira Khan', code: 'A').initials,
        'AK',
      );
      expect(const Friend(uid: 'u', name: 'amira', code: 'A').initials, 'A');
      expect(const Friend(uid: 'u', name: '  ', code: 'A').initials, '?');
    });
  });
}
