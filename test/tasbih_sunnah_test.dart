import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noor/core/services/prefs_service.dart';
import 'package:noor/features/tasbih/application/tasbih_controller.dart';
import 'package:noor/features/tasbih/domain/dhikr.dart';
import 'package:noor/features/tasbih/domain/sunnah_routine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The after-prayer sequence hands off between three dhikr on its own. Getting
/// a boundary wrong is the kind of thing nobody notices until they have
/// miscounted their dhikr, so the handoffs are pinned exactly.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> boot() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        tasbihPaceProvider.overrideWithValue(false),
        prefsProvider.overrideWithValue(PrefsService(prefs)),
      ],
    );
    addTearDown(container.dispose);
    container.read(tasbihProvider.notifier).setMode(TasbihMode.sunnah);
    return container;
  }

  void tap(ProviderContainer c, int times) {
    for (int i = 0; i < times; i++) {
      c.read(tasbihProvider.notifier).increment();
    }
  }

  test('starts on SubhanAllah, 33', () async {
    final ProviderContainer c = await boot();
    final TasbihState s = c.read(tasbihProvider);
    expect(s.dhikr.name, 'SubhanAllah');
    expect(s.target, 33);
    expect(s.count, 0);
  });

  test('the 33rd SubhanAllah hands over to Alhamdulillah', () async {
    final ProviderContainer c = await boot();

    tap(c, 32);
    expect(c.read(tasbihProvider).dhikr.name, 'SubhanAllah');
    expect(c.read(tasbihProvider).count, 32, reason: 'still one short');

    tap(c, 1);
    final TasbihState s = c.read(tasbihProvider);
    expect(s.dhikr.name, 'Alhamdulillah');
    expect(
      s.count,
      0,
      reason:
          'the 33rd completes SubhanAllah; it does not count towards '
          'the next dhikr',
    );
    expect(s.target, 33);
  });

  test('Alhamdulillah hands over to Allahu Akbar, which asks for 34', () async {
    final ProviderContainer c = await boot();
    tap(c, 66);
    final TasbihState s = c.read(tasbihProvider);
    expect(s.dhikr.name, 'Allahu Akbar');
    expect(s.count, 0);
    expect(s.target, 34, reason: '33 + 33 + 34 is the hundred');
  });

  test('the hundredth completes the round and returns to the start', () async {
    final ProviderContainer c = await boot();

    tap(c, 99);
    expect(c.read(tasbihProvider).roundsCompleted, 0, reason: 'not yet');
    expect(c.read(tasbihProvider).dhikr.name, 'Allahu Akbar');

    tap(c, 1);
    final TasbihState s = c.read(tasbihProvider);
    expect(s.roundsCompleted, 1);
    expect(s.setsCompleted, 1);
    expect(s.dhikr.name, 'SubhanAllah', reason: 'ready for the next prayer');
    expect(s.stage, 0);
    expect(s.count, 0);
  });

  test('progress through the hundred accounts for finished stages', () async {
    final ProviderContainer c = await boot();
    tap(c, 40);
    // 33 SubhanAllah behind us, 7 into Alhamdulillah.
    expect(c.read(tasbihProvider).sunnahDone, 40);
    expect(c.read(tasbihProvider).count, 7);
  });

  test('reset goes back to the first dhikr, not just to zero', () async {
    final ProviderContainer c = await boot();
    tap(c, 70);
    expect(c.read(tasbihProvider).dhikr.name, 'Allahu Akbar');

    c.read(tasbihProvider.notifier).reset();
    final TasbihState s = c.read(tasbihProvider);
    expect(s.dhikr.name, 'SubhanAllah');
    expect(s.stage, 0);
    expect(s.count, 0);
  });

  test('switching to Manual and back starts the sequence clean', () async {
    final ProviderContainer c = await boot();
    tap(c, 40);

    c.read(tasbihProvider.notifier).setMode(TasbihMode.manual);
    expect(c.read(tasbihProvider).count, 0);

    c.read(tasbihProvider.notifier).setMode(TasbihMode.sunnah);
    final TasbihState s = c.read(tasbihProvider);
    expect(s.dhikr.name, 'SubhanAllah');
    expect(s.stage, 0);
    expect(s.count, 0);
  });

  test('a restart resumes mid-sequence with the right target', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final ProviderContainer first = ProviderContainer(
      overrides: <Override>[
        tasbihPaceProvider.overrideWithValue(false),
        prefsProvider.overrideWithValue(PrefsService(prefs)),
      ],
    );
    first.read(tasbihProvider.notifier).setMode(TasbihMode.sunnah);
    for (int i = 0; i < 70; i++) {
      first.read(tasbihProvider.notifier).increment();
    }
    first.dispose();

    // A fresh container over the same storage, as a cold launch would be.
    final ProviderContainer second = ProviderContainer(
      overrides: <Override>[
        tasbihPaceProvider.overrideWithValue(false),
        prefsProvider.overrideWithValue(PrefsService(prefs)),
      ],
    );
    addTearDown(second.dispose);
    final TasbihState s = second.read(tasbihProvider);
    expect(s.mode, TasbihMode.sunnah);
    expect(s.dhikr.name, 'Allahu Akbar');
    expect(s.target, 34);
    expect(s.count, 4);
  });

  test('after prayer is the sequence Sahih Muslim 596a describes', () {
    expect(
      SunnahRoutine.afterPrayer.stages
          .map((Dhikr d) => d.defaultTarget)
          .toList(),
      <int>[33, 33, 34],
    );
    expect(SunnahRoutine.afterPrayer.total, 100);
  });

  test('before sleep leads with the takbir, as its narration does', () {
    // Bukhari 3113 gives 34 takbir first. After prayer closes on it instead.
    // Same hundred, different order — neither should be tidied into the other.
    expect(SunnahRoutine.beforeSleep.stages.first.name, 'Allahu Akbar');
    expect(SunnahRoutine.beforeSleep.stages.first.defaultTarget, 34);
    expect(
      SunnahRoutine.beforeSleep.stages.map((Dhikr d) => d.defaultTarget),
      <int>[34, 33, 33],
    );
    expect(SunnahRoutine.beforeSleep.total, 100);
    expect(SunnahRoutine.afterPrayer.stages.first.name, 'SubhanAllah');
  });

  test('a recited stage is short; a counted one is not', () {
    // The screen swaps the tap-ring for the words and a Done button at this
    // boundary, so it decides how every routine is performed.
    expect(Dhikr.juwayriyah.isRecited, isTrue, reason: 'x3 is read');
    expect(Dhikr.raditu.isRecited, isTrue);
    expect(Dhikr.subhanAllah.isRecited, isFalse, reason: 'x33 is counted');
    expect(Dhikr.tahlil.isRecited, isFalse, reason: 'x100 is counted');
  });

  test('long phrases carry a full transliteration, not just a label', () {
    for (final Dhikr d in <Dhikr>[
      Dhikr.tahlil,
      Dhikr.juwayriyah,
      Dhikr.raditu,
    ]) {
      expect(
        d.spoken.length,
        greaterThan(d.name.length),
        reason:
            '${d.name} is abbreviated in the label, so the recitation '
            'card needs the whole phrase',
      );
    }
    expect(Dhikr.subhanAllah.spoken, Dhikr.subhanAllah.name);
  });

  test('every routine is grouped and gives its virtue', () {
    for (final SunnahRoutine r in SunnahRoutine.all) {
      expect(r.virtue, isNotEmpty, reason: '${r.id} has no virtue');
      expect(r.groups, isNotEmpty, reason: '${r.id} is in no section');
      for (final RoutineGroup g in r.groups) {
        expect(
          SunnahRoutine.inGroup(g),
          contains(r),
          reason: '${r.id} is missing from ${g.name}',
        );
      }
    }
  });

  test('every routine carries a narration and a reference', () {
    for (final SunnahRoutine r in SunnahRoutine.all) {
      expect(r.narration, isNotEmpty, reason: '${r.id} has no narration');
      expect(r.reference, isNotEmpty, reason: '${r.id} has no reference');
      expect(r.total, greaterThan(0), reason: '${r.id} counts to nothing');
      expect(r.stages, isNotEmpty);
    }
  });

  test('routine ids are unique and stable', () {
    final Set<String> ids = SunnahRoutine.all
        .map((SunnahRoutine r) => r.id)
        .toSet();
    expect(ids.length, SunnahRoutine.all.length);
    // Ids are written into preferences; renaming one silently resets whatever
    // a user had chosen.
    expect(
      ids,
      containsAll(<String>[
        'after_prayer',
        'before_sleep',
        'tasbih_100',
        'tahlil_100',
        'istighfar_100',
        'juwayriyah_3',
        'raditu_3',
        'tasbih_morning_evening',
      ]),
    );
  });

  test('only the hasan report is labelled, and it is labelled', () {
    expect(SunnahRoutine.raditu.grading, 'Hasan');
    final Iterable<SunnahRoutine> unlabelled = SunnahRoutine.all.where(
      (SunnahRoutine r) => r.grading == null,
    );
    for (final SunnahRoutine r in unlabelled) {
      expect(
        r.reference,
        anyOf(contains('Bukhari'), contains('Muslim')),
        reason: '${r.id} is unlabelled, so it must be from the two Sahihs',
      );
    }
  });

  test('no section of the picker is empty', () {
    for (final RoutineGroup g in RoutineGroup.values) {
      expect(
        SunnahRoutine.inGroup(g),
        isNotEmpty,
        reason: '${g.label} would render as a heading with nothing under it',
      );
    }
  });

  test('the two SubhanAllahi wa bihamdihi hundreds stay separate', () {
    // Bukhari 6405 is a hundred a day; Muslim 2692 is a hundred morning and a
    // hundred evening. Same words, different reports and different promises,
    // so merging them into one card would misattribute both.
    expect(SunnahRoutine.tasbihHundred.reference, contains('6405'));
    expect(SunnahRoutine.tasbihMorningEvening.reference, contains('2692'));
    expect(
      SunnahRoutine.tasbihHundred.id,
      isNot(SunnahRoutine.tasbihMorningEvening.id),
    );
    expect(SunnahRoutine.tasbihMorningEvening.groups, <RoutineGroup>{
      RoutineGroup.morning,
      RoutineGroup.evening,
    });
  });

  test('foam of the sea sits with the hundred it belongs to', () {
    // Bukhari 6405 attaches it to SubhanAllahi wa bihamdihi x100 — not to the
    // after-prayer 33/33/34, where the other app put it.
    expect(SunnahRoutine.tasbihHundred.narration, contains('foam of the sea'));
    expect(SunnahRoutine.tasbihHundred.reference, contains('6405'));
    expect(
      SunnahRoutine.afterPrayer.narration,
      isNot(contains('foam of the sea')),
    );
  });

  test('single-dhikr routines do not claim stages', () {
    for (final SunnahRoutine r in SunnahRoutine.all) {
      expect(r.hasStages, r.stages.length > 1, reason: r.id);
    }
    expect(SunnahRoutine.juwayriyah.hasStages, isFalse);
    expect(SunnahRoutine.juwayriyah.total, 3);
  });

  test('each routine counts to its own total and then completes', () async {
    for (final SunnahRoutine routine in SunnahRoutine.all) {
      final ProviderContainer c = await boot();
      c.read(tasbihProvider.notifier).setRoutine(routine);

      for (int i = 0; i < routine.total - 1; i++) {
        c.read(tasbihProvider.notifier).increment();
      }
      expect(
        c.read(tasbihProvider).roundsCompleted,
        0,
        reason: '${routine.id} finished early',
      );

      c.read(tasbihProvider.notifier).increment();
      final TasbihState s = c.read(tasbihProvider);
      expect(s.roundsCompleted, 1, reason: '${routine.id} did not finish');
      expect(s.stage, 0);
      expect(s.count, 0);
      expect(s.dhikr.name, routine.stages.first.name);
    }
  });
}
