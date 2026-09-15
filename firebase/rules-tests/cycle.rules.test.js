/**
 * Executable security-rules tests for the Layla Pro prayer pause.
 *
 * A woman does not pray during menstruation, and those prayers are not made up
 * afterwards. The app has to know when a pause is on so that it stops asking,
 * stops nagging, marks nothing missed and does not break a streak she has kept
 * for months. Knowing that makes this the most sensitive thing the database
 * holds about anybody, and it is stored in exactly two places, both of which
 * only their owner can read:
 *
 *   users/{uid}.cycle      absent or null when no pause is on, and exactly
 *                          { startedOn: 'yyyy-MM-dd' } while one is.
 *   users/{uid}.gender     'brother' or 'sister', the onboarding answer that
 *                          decides whether the pause is offered at all. In
 *                          Firestore only so that it survives signing out.
 *   users/{uid}/prayer_days/{date}.excused
 *                          the day itself, so the streak can be carried across
 *                          it rather than broken by it.
 *
 * Two questions are being asked here, and the second matters more than the
 * first. Is the shape bounded — so that a hand-written or buggy document can
 * never reach the branch that decides whether to ask a woman to pray? And can
 * a friend tell? A friend can legitimately read progress/{uid}: this suite
 * proves that reading it tells them nothing, that a client cannot add anything
 * to it that would, and that they cannot reach either of the private places
 * where the answer actually lives.
 *
 * Runs against the real rules file, read off disk, beside friends.rules.test.js
 * and avatar.rules.test.js.
 *
 * Run with:   npm run emu     (starts the Firestore emulator, runs, shuts down)
 * or, against an emulator you already have running on 127.0.0.1:8080:
 *             npm test
 */
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  Bytes,
  deleteField,
  getDoc,
  getDocs,
  setDoc,
  setLogLevel,
  updateDoc,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';

import {
  db,
  fullAccount,
  guestAccount,
  makeTestEnv,
  prayerDayRef,
  prayerDaysRef,
  progressDoc,
  progressRef,
  seedClaimedCode,
  seedListEntry,
  seedPrayerDay,
  seedProgress,
  seedUser,
  userRef,
} from './support/env.js';

// The same people and codes as the other two suites.
const ME = 'uid_me';
const THEM = 'uid_them';
const STRANGER = 'uid_stranger';

const MY_CODE = 'ABC234';
const THEIR_CODE = 'XYZ789';

// A day id, in the shape Fmt.dayId produces and every other date in this app
// is keyed by.
const DAY = '2026-09-14';
const LATER_DAY = '2026-09-17';
// The day before DAY. What the chain reaches for anybody whose streak is alive
// but who has not finished today — which, as below, includes a paused day.
const DAY_BEFORE = '2026-09-13';

/// The pause, turned on. The only shape users/{uid}.cycle may ever hold.
const PAUSE_ON = { startedOn: DAY };

/// The eleven keys progress/{uid} is allowed to carry, and the whole of the
/// privacy guarantee on the friend-visible side: what is not in this list
/// cannot be written, so it cannot be read.
const PUBLISHED_KEYS = [
  'code',
  'lastCompletedDate',
  'longestStreak',
  'name',
  'photo',
  'streak',
  'todayCompleted',
  'todayDate',
  'totalPrayers',
  'totalTahajjud',
  'updatedAt',
];

/// A complete profile write of the kind the app already makes, with no pause
/// and no gender anywhere in it. The regression guard's raw material: none of
/// this existed under any rule before the pause arrived, and all of it has to
/// go on passing untouched.
function ordinaryProfile(overrides = {}) {
  return {
    displayName: 'Aisha',
    friendCode: MY_CODE,
    settings: { theme: 'dark', adhanVoice: 'makkah' },
    location: { lat: 51.5074, lng: -0.1278, city: 'London' },
    stats: { totalPrayers: 900, streak: 3 },
    ...overrides,
  };
}

/// A day the pause covered, as PrayerDayRepository leaves it: the day flagged,
/// and five records carrying `excused` rather than `missed`, because nothing on
/// a paused day is ever owed.
function excusedDay() {
  return {
    dateId: DAY,
    excused: true,
    records: {
      fajr: { status: 'excused' },
      dhuhr: { status: 'excused' },
      asr: { status: 'excused' },
      maghrib: { status: 'excused' },
      isha: { status: 'excused' },
    },
    tahajjudPrayed: false,
  };
}

let env;

beforeAll(async () => {
  // The SDK shouts about every expected permission-denied otherwise.
  setLogLevel('error');
  env = await makeTestEnv();
});

afterAll(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

// ═══════════════════════════════════════════════════════════════════════════
// THE SHAPE OF THE PAUSE — users/{uid}.cycle is either not there at all, or
// it is exactly { startedOn: 'yyyy-MM-dd' }. Anything in between is a state
// the app would have to invent a meaning for, on the screen where inventing
// one is least forgivable.
// ═══════════════════════════════════════════════════════════════════════════
describe('cycle: shapes that must be refused', () => {
  test('1. a cycle carrying any key beyond startedOn is refused', async () => {
    const d = db(fullAccount(env, ME));

    // Nothing else belongs on it, and the two most tempting extras are the
    // two that must never be stored: a predicted end date would be the app
    // deciding on her behalf that the pause is over, and a note is free text
    // about the most private thing here.
    await assertFails(
      setDoc(
        userRef(d, ME),
        ordinaryProfile({ cycle: { startedOn: DAY, endedOn: LATER_DAY } }),
      ),
    );
    await assertFails(
      setDoc(
        userRef(d, ME),
        ordinaryProfile({ cycle: { startedOn: DAY, note: 'heavy' } }),
      ),
    );
    await assertFails(
      setDoc(
        userRef(d, ME),
        ordinaryProfile({ cycle: { startedOn: DAY, dayCount: 3 } }),
      ),
    );

    // And onto a profile that is already there, by both shapes of write the
    // app makes.
    await seedUser(env, ME, ordinaryProfile());
    await assertFails(
      setDoc(
        userRef(d, ME),
        { cycle: { startedOn: DAY, endedOn: LATER_DAY } },
        { merge: true },
      ),
    );
    await assertFails(
      updateDoc(userRef(d, ME), {
        cycle: { startedOn: DAY, endedOn: LATER_DAY },
      }),
    );
  });

  test('2. a cycle with no startedOn at all is refused', async () => {
    const d = db(fullAccount(env, ME));

    // An empty map is the dangerous one. It is neither "a pause is on" nor
    // "no pause is on", so Home would have to pick one — and picking wrong in
    // either direction is either nagging a woman to pray during her period or
    // silently suppressing five prayers a day for somebody who is not in one.
    await assertFails(setDoc(userRef(d, ME), ordinaryProfile({ cycle: {} })));

    // Explicit null in the field, which a map with the key present but empty
    // would also be.
    await assertFails(
      setDoc(userRef(d, ME), ordinaryProfile({ cycle: { startedOn: null } })),
    );

    // A map with a different single key is the same hole by another route.
    await assertFails(
      setDoc(userRef(d, ME), ordinaryProfile({ cycle: { began: DAY } })),
    );
  });

  test('3. a cycle that is not a map is refused', async () => {
    const d = db(fullAccount(env, ME));

    // The field is read as a map by the code that decides whether to show the
    // pause. Every one of these would make that read throw or, worse, read
    // truthy and turn the pause on for a value that meant nothing.
    await assertFails(setDoc(userRef(d, ME), ordinaryProfile({ cycle: DAY })));
    await assertFails(setDoc(userRef(d, ME), ordinaryProfile({ cycle: true })));
    await assertFails(setDoc(userRef(d, ME), ordinaryProfile({ cycle: 3 })));
    await assertFails(
      setDoc(userRef(d, ME), ordinaryProfile({ cycle: [PAUSE_ON] })),
    );
    await assertFails(
      setDoc(
        userRef(d, ME),
        ordinaryProfile({ cycle: Bytes.fromUint8Array(new Uint8Array([1])) }),
      ),
    );
  });

  test('4. a startedOn that is not a string is refused', async () => {
    const d = db(fullAccount(env, ME));

    // A timestamp is the one that would slip past a careless rule, because it
    // is what a Firestore document "should" hold a date in. It is refused on
    // purpose: everything in this app is keyed by Fmt.dayId, and the number
    // Home shows is a count of days. Counting days from instants gives a pause
    // that reads "Day 3" in one time zone and "Day 2" in another.
    await assertFails(
      setDoc(userRef(d, ME), ordinaryProfile({ cycle: { startedOn: 20260914 } })),
    );
    await assertFails(
      setDoc(userRef(d, ME), ordinaryProfile({ cycle: { startedOn: true } })),
    );
    await assertFails(
      setDoc(userRef(d, ME), ordinaryProfile({ cycle: { startedOn: [DAY] } })),
    );
    await assertFails(
      setDoc(
        userRef(d, ME),
        ordinaryProfile({ cycle: { startedOn: new Date(2026, 8, 14) } }),
      ),
    );
  });

  test('5. a startedOn that is not a day id is refused', async () => {
    const d = db(fullAccount(env, ME));

    // Each of these is a string, so only the pattern refuses it. The day count
    // on Home is arithmetic on this value; a string that is not a date makes
    // that arithmetic produce a number nobody can explain, next to the words
    // "Day".
    for (const bad of [
      '',
      '2026-9-14',
      '14/09/2026',
      '2026-09-14T00:00:00Z',
      'yesterday',
      '2026-09-144',
      ' 2026-09-14',
    ]) {
      await assertFails(
        setDoc(userRef(d, ME), ordinaryProfile({ cycle: { startedOn: bad } })),
      );
    }
  });

  test('6. nobody can turn a pause on, or off, for somebody else', async () => {
    await seedUser(env, ME, ordinaryProfile({ cycle: PAUSE_ON }));

    // The profile was always owner-only; this is the thing that rule is now
    // guarding. A stranger cannot start one on her behalf, cannot end one, and
    // cannot read whether there is one.
    const stranger = db(fullAccount(env, STRANGER));
    await assertFails(
      setDoc(userRef(stranger, ME), { cycle: PAUSE_ON }, { merge: true }),
    );
    await assertFails(
      setDoc(userRef(stranger, ME), { cycle: null }, { merge: true }),
    );
    await assertFails(getDoc(userRef(stranger, ME)));

    // And neither can a friend, who is the person with an actual reason to
    // wonder. Being on her list buys a scoreboard and nothing else.
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedListEntry(env, ME, THEM, 'Yusuf', THEIR_CODE);
    const friend = db(fullAccount(env, THEM));
    await assertFails(getDoc(userRef(friend, ME)));
    await assertFails(
      setDoc(userRef(friend, ME), { cycle: null }, { merge: true }),
    );
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// THE SHAPE OF THE ANSWER — users/{uid}.gender is one of two words, and the
// branch that reads it must never have a third case to handle.
// ═══════════════════════════════════════════════════════════════════════════
describe('gender: values that must be refused', () => {
  test('7. any value other than the two GenderStep produces is refused', async () => {
    const d = db(fullAccount(env, ME));

    // Case included. The read is an equality test against 'sister', so a
    // capitalised one is not a near-miss that degrades gracefully — it is a
    // woman who answered the question and is never offered the pause, with
    // nothing anywhere to say why.
    for (const bad of [
      'Sister',
      'SISTER',
      'sisters',
      'sister ',
      'female',
      'f',
      'other',
      '',
    ]) {
      await assertFails(
        setDoc(userRef(d, ME), ordinaryProfile({ gender: bad })),
      );
    }
  });

  test('8. a gender that is not a string is refused', async () => {
    const d = db(fullAccount(env, ME));

    await assertFails(setDoc(userRef(d, ME), ordinaryProfile({ gender: 1 })));
    await assertFails(setDoc(userRef(d, ME), ordinaryProfile({ gender: true })));
    await assertFails(
      setDoc(userRef(d, ME), ordinaryProfile({ gender: ['sister'] })),
    );
    await assertFails(
      setDoc(userRef(d, ME), ordinaryProfile({ gender: { value: 'sister' } })),
    );
  });

  test('9. a bad gender is refused on a merge and an update, not only a create', async () => {
    await seedUser(env, ME, ordinaryProfile({ gender: 'sister' }));
    const d = db(fullAccount(env, ME));

    // A merge is evaluated against the document it would produce, so this is
    // the shape that matters: the profile is already good, and the write that
    // would spoil it has to be the one refused.
    await assertFails(
      setDoc(userRef(d, ME), { gender: 'other' }, { merge: true }),
    );
    await assertFails(updateDoc(userRef(d, ME), { gender: 'other' }));

    // The good value is still there, untouched.
    const snap = await assertSucceeds(getDoc(userRef(d, ME)));
    expect(snap.data().gender).toBe('sister');
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// THE HONEST CLIENT — a failure in here is a woman who cannot turn the pause
// on, or cannot turn it off, and the last two are the guard that the new
// clauses broke nothing that already worked.
// ═══════════════════════════════════════════════════════════════════════════
describe('the honest client', () => {
  test('a. turns the pause on with exactly { startedOn }', async () => {
    await seedUser(env, ME, ordinaryProfile({ gender: 'sister' }));
    const d = db(fullAccount(env, ME));

    // What the app writes when she says it has started: one merge, one key.
    await assertSucceeds(
      setDoc(userRef(d, ME), { cycle: PAUSE_ON }, { merge: true }),
    );
    await assertSucceeds(
      updateDoc(userRef(d, ME), { cycle: { startedOn: LATER_DAY } }),
    );

    // And on a profile created from nothing with the pause already on, which
    // is what a reinstall restoring from a backup would write.
    const snap = await assertSucceeds(getDoc(userRef(d, ME)));
    expect(snap.data().cycle).toEqual({ startedOn: LATER_DAY });
  });

  test('b. turns the pause off, by null and by deletion', async () => {
    await seedUser(env, ME, ordinaryProfile({ cycle: PAUSE_ON }));
    const d = db(fullAccount(env, ME));

    // Ending it has to be at least as easy as starting it — the app must never
    // end it by itself, so this write is the only way out, and it cannot be
    // the one the rules refuse. Both shapes work: the explicit null the
    // controller sends, and the deletion that does the same job.
    await assertSucceeds(
      setDoc(userRef(d, ME), { cycle: null }, { merge: true }),
    );
    await assertSucceeds(
      setDoc(userRef(d, ME), { cycle: PAUSE_ON }, { merge: true }),
    );
    await assertSucceeds(updateDoc(userRef(d, ME), { cycle: deleteField() }));

    const snap = await assertSucceeds(getDoc(userRef(d, ME)));
    expect(snap.data().cycle).toBeUndefined();
  });

  test('c. writes either gender, and takes it back off', async () => {
    const d = db(fullAccount(env, ME));

    // Both values the onboarding question produces, written at sign-up…
    await assertSucceeds(
      setDoc(userRef(d, ME), ordinaryProfile({ gender: 'sister' })),
    );
    await assertSucceeds(
      setDoc(userRef(d, ME), { gender: 'brother' }, { merge: true }),
    );

    // …and absent or null, which is every build that shipped before the
    // question was persisted at all, plus anyone who skipped it.
    await assertSucceeds(
      setDoc(userRef(d, ME), { gender: null }, { merge: true }),
    );
    await assertSucceeds(updateDoc(userRef(d, ME), { gender: deleteField() }));
    await assertSucceeds(setDoc(userRef(d, ME), ordinaryProfile()));
  });

  test('d. lets a guest use the pause on their own profile', async () => {
    // users/{uid} asks for isOwner, not isFullAccount. A guest who has not
    // made an account still prays, still needs the pause, and their profile is
    // read by nobody else — so nothing here may turn on having signed up.
    const d = db(guestAccount(env, ME));

    await assertSucceeds(
      setDoc(userRef(d, ME), ordinaryProfile({ gender: 'sister' })),
    );
    await assertSucceeds(
      setDoc(userRef(d, ME), { cycle: PAUSE_ON }, { merge: true }),
    );
    await assertSucceeds(
      setDoc(userRef(d, ME), { cycle: null }, { merge: true }),
    );
  });

  test('e. writes the whole sign-up profile with gender on it from the start', async () => {
    // The contract says gender is written at sign-up and again at onboarding
    // completion, so the seed write now carries a key it never carried before.
    // If this were refused, signing up would fail outright.
    const d = db(fullAccount(env, ME));

    await assertSucceeds(
      setDoc(
        userRef(d, ME),
        ordinaryProfile({ gender: 'sister', cycle: null }),
      ),
    );
    await assertSucceeds(
      setDoc(userRef(d, ME), { gender: 'sister' }, { merge: true }),
    );
  });

  test('f. makes every profile write it made before, untouched', async () => {
    // The regression guard. Two clauses became four on this document, and none
    // of them may have turned a write that mentions neither key into a shape
    // the rules have an opinion about.
    const d = db(fullAccount(env, ME));

    await assertSucceeds(setDoc(userRef(d, ME), ordinaryProfile()));
    await assertSucceeds(
      setDoc(userRef(d, ME), { displayName: 'Aisha K' }, { merge: true }),
    );
    await assertSucceeds(
      setDoc(userRef(d, ME), { settings: { theme: 'light' } }, { merge: true }),
    );
    await assertSucceeds(
      setDoc(
        userRef(d, ME),
        { location: { lat: 21.4225, lng: 39.8262, city: 'Makkah' } },
        { merge: true },
      ),
    );
    await assertSucceeds(
      setDoc(userRef(d, ME), { stats: { streak: 4 } }, { merge: true }),
    );
    await assertSucceeds(
      setDoc(userRef(d, ME), { friendCode: MY_CODE }, { merge: true }),
    );
    await assertSucceeds(updateDoc(userRef(d, ME), { displayName: 'Aisha' }));

    // And the same writes again over a profile that DOES have a pause on it,
    // because a merge is evaluated against the document it produces: an
    // ordinary write must not be refused for a field it never mentioned, and
    // must not be able to spoil that field by omission either.
    await assertSucceeds(
      setDoc(
        userRef(d, ME),
        { cycle: PAUSE_ON, gender: 'sister' },
        { merge: true },
      ),
    );
    await assertSucceeds(
      setDoc(userRef(d, ME), { stats: { streak: 5 } }, { merge: true }),
    );
    const snap = await assertSucceeds(getDoc(userRef(d, ME)));
    expect(snap.data().cycle).toEqual(PAUSE_ON);
  });

  test('g. still writes a picture, with a pause on, in one merge', async () => {
    // The four clauses on this document are independent, and this proves they
    // compose: the avatar suite's write and this suite's write in one go.
    await seedUser(env, ME, ordinaryProfile());
    const d = db(fullAccount(env, ME));

    await assertSucceeds(
      setDoc(
        userRef(d, ME),
        { photo: 'QUJD', photoThumb: 'QUJD', gender: 'sister', cycle: PAUSE_ON },
        { merge: true },
      ),
    );

    // And a bad picture is still refused when the pause fields are good, which
    // is what proves neither clause is swallowing the other.
    await assertFails(
      setDoc(
        userRef(d, ME),
        { photo: 'not base64!!', cycle: PAUSE_ON },
        { merge: true },
      ),
    );
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// THE EXCUSED DAY — users/{uid}/prayer_days/{date} is where a paused day is
// actually recorded. The rule on it is unchanged and unvalidated by design,
// so its read side is the entire protection, and these are the tests that say
// so out loud.
// ═══════════════════════════════════════════════════════════════════════════
describe('prayer days: the excused day stays private', () => {
  test('h. the owner writes and reads an excused day', async () => {
    const d = db(fullAccount(env, ME));

    await assertSucceeds(setDoc(prayerDayRef(d, ME, DAY), excusedDay()));
    const snap = await assertSucceeds(getDoc(prayerDayRef(d, ME, DAY)));
    expect(snap.data().excused).toBe(true);
    expect(snap.data().records.fajr.status).toBe('excused');

    // A guest's days are their own too — nothing here turns on having an
    // account, and a guest who cannot record an excused day gets her streak
    // broken by it instead.
    const guest = db(guestAccount(env, THEM));
    await assertSucceeds(setDoc(prayerDayRef(guest, THEM, DAY), excusedDay()));
  });

  test('i. a stranger cannot read a prayer day', async () => {
    await seedPrayerDay(env, ME, DAY, excusedDay());
    const d = db(fullAccount(env, STRANGER));

    // This is the document that says, in a field called `excused`, that a
    // woman was menstruating on a named date. Reading one is the whole attack.
    await assertFails(getDoc(prayerDayRef(d, ME, DAY)));

    // Nor the collection, which would hand over every such date at once.
    await assertFails(getDocs(prayerDaysRef(d, ME)));

    // Nor write one — a forged excused day would suppress five prayers a day
    // for somebody who never asked for it, and the rule that stops it is the
    // same one.
    await assertFails(setDoc(prayerDayRef(d, ME, LATER_DAY), excusedDay()));
  });

  test('j. a friend cannot read a prayer day either', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedProgress(env, ME, MY_CODE);
    await seedListEntry(env, ME, THEM, 'Yusuf', THEIR_CODE);
    await seedPrayerDay(env, ME, DAY, excusedDay());
    const d = db(fullAccount(env, THEM));

    // The friend is legitimate — they are on her list and their scoreboard
    // read succeeds on the very next line. That is exactly what makes this the
    // test worth having: the access they DO have stops at progress/{uid}.
    await assertSucceeds(getDoc(progressRef(d, ME)));

    await assertFails(getDoc(prayerDayRef(d, ME, DAY)));
    await assertFails(getDocs(prayerDaysRef(d, ME)));
    await assertFails(getDoc(userRef(d, ME)));
  });

  test('k. a guest on the list cannot read a prayer day', async () => {
    // Belt and braces on the weakest kind of account that can hold a place on
    // somebody's list.
    await seedPrayerDay(env, ME, DAY, excusedDay());
    await seedListEntry(env, ME, THEM, 'Yusuf', THEIR_CODE);
    const d = db(guestAccount(env, THEM));

    await assertFails(getDoc(prayerDayRef(d, ME, DAY)));
    await assertFails(getDoc(userRef(d, ME)));
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// THE PRIVACY GUARANTEE — the test that actually matters.
//
// A friend can read progress/{uid}. That is the point of Friends. So the
// question is not whether the pause is hidden from the world, it is whether it
// is hidden from the one person who has legitimate read access to something.
// These prove: nothing about the pause is in what they read, nothing can be
// put there, and the two places it does live are closed to them.
// ═══════════════════════════════════════════════════════════════════════════
describe('a friend cannot tell', () => {
  test('l. a friend reading the scoreboard sees no cycle, no gender, no excused', async () => {
    // The whole round trip. Her profile holds the pause, the day is marked
    // excused, and her phone publishes the scoreboard as it always does.
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedUser(env, ME, ordinaryProfile({ gender: 'sister', cycle: PAUSE_ON }));
    await seedPrayerDay(env, ME, DAY, excusedDay());
    await seedListEntry(env, ME, THEM, 'Yusuf', THEIR_CODE);

    // Published with a picture on it, so that every key the scoreboard is
    // allowed to carry is actually present — an absent optional field would
    // make the key-set assertion below pass for the wrong reason.
    const mine = db(fullAccount(env, ME));
    await assertSucceeds(
      setDoc(
        progressRef(mine, ME),
        progressDoc(MY_CODE, { todayCompleted: 0, photo: 'QUJD' }),
      ),
    );

    const d = db(fullAccount(env, THEM));
    const snap = await assertSucceeds(getDoc(progressRef(d, ME)));
    const seen = snap.data();

    // Not a single one of the three words appears in what they receive.
    expect(seen.cycle).toBeUndefined();
    expect(seen.gender).toBeUndefined();
    expect(seen.excused).toBeUndefined();

    // And nothing else has appeared either. Asserting the exact key set rather
    // than the three absences is the assertion with a future in it: it fails on
    // a fourth field nobody has thought of yet.
    expect(Object.keys(seen).sort()).toEqual(PUBLISHED_KEYS);
  });

  test('m. adding cycle to the scoreboard is refused', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));

    // The existing keys().hasOnly clause is what refuses these — nothing was
    // added to progress/{uid} for the pause, and this is the test that says
    // nothing may be. Whole map, and the flattened variants a well-meaning
    // patch might reach for instead.
    await assertFails(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { cycle: PAUSE_ON })),
    );
    await assertFails(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { cycle: null })),
    );
    await assertFails(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { cycleStartedOn: DAY })),
    );
    await assertFails(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { paused: true })),
    );
  });

  test('n. adding gender to the scoreboard is refused', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));

    // Gender is not secret in the way the pause is, but on this document it is
    // the field that makes a quiet week legible: a friend who knows the answer
    // is 'sister' and sees five days of nothing has been told something she
    // did not tell them.
    await assertFails(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { gender: 'sister' })),
    );
    await assertFails(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { gender: 'brother' })),
    );
    await assertFails(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { gender: null })),
    );
  });

  test('o. adding excused to the scoreboard is refused', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));

    // Including the shapes that look harmless. `excusedToday: false` is a
    // field whose false is as loud as its true, because it only ever appears
    // on accounts that could have a pause at all.
    await assertFails(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { excused: true })),
    );
    await assertFails(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { excused: false })),
    );
    await assertFails(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { excusedToday: false })),
    );
    await assertFails(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { excusedDays: [DAY] })),
    );

    // And on an update to a scoreboard that is already published, not only on
    // the first write.
    await seedProgress(env, ME, MY_CODE);
    await assertFails(updateDoc(progressRef(d, ME), { excused: true }));
  });

  test('p. a paused day publishes the same scoreboard as an ordinary quiet one', async () => {
    // The last piece, and the one no rule can enforce on its own: even with
    // the three keys refused, the pause would still be visible if the old
    // fields moved differently during one. They do not. This is the document
    // her phone publishes on day three of a pause…
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedListEntry(env, ME, THEM, 'Yusuf', THEIR_CODE);
    const mine = db(fullAccount(env, ME));

    const duringPause = progressDoc(MY_CODE, {
      todayCompleted: 0,
      todayDate: DAY,
      // The streak is carried, not broken: an excused day neither ends the
      // chain nor lengthens it, so this reads what it read before the pause.
      streak: 11,
      // Yesterday, not today — even though the profile's own stats say today.
      // Carrying the chain onto an excused day is what keeps the streak alive,
      // but publishing that date next to a count of zero would be a pair no
      // ordinary day can produce, and a friend could read the pause straight
      // off it. `_lastCompletedForFriends` in friends_controller.dart holds it
      // back to yesterday, which keeps the chain alive on their phone and
      // matches the quiet scoreboard below exactly.
      lastCompletedDate: DAY_BEFORE,
    });
    await assertSucceeds(setDoc(progressRef(mine, ME), duringPause));

    const d = db(fullAccount(env, THEM));
    const paused = (await assertSucceeds(getDoc(progressRef(d, ME)))).data();

    // …and this is somebody who simply has not prayed yet today, with the same
    // streak behind them. A friend holding both cannot tell which is which.
    await seedClaimedCode(env, THEM, THEIR_CODE, 'Yusuf');
    await seedListEntry(env, THEM, ME, 'Aisha', MY_CODE);
    const theirs = db(fullAccount(env, THEM));
    await assertSucceeds(
      setDoc(
        progressRef(theirs, THEM),
        progressDoc(THEIR_CODE, {
          name: 'Yusuf',
          todayCompleted: 0,
          todayDate: DAY,
          streak: 11,
          // Their chain was last carried yesterday, because they finished
          // yesterday and have not prayed yet today.
          lastCompletedDate: DAY_BEFORE,
        }),
      ),
    );
    const notYet = (
      await assertSucceeds(getDoc(progressRef(db(fullAccount(env, ME)), THEM)))
    ).data();

    expect(Object.keys(paused).sort()).toEqual(Object.keys(notYet).sort());
    expect(paused.todayCompleted).toBe(notYet.todayCompleted);
    expect(paused.streak).toBe(notYet.streak);
    expect(paused.lastCompletedDate).toBe(notYet.lastCompletedDate);

    // Named outright, so this test cannot go quietly vacuous again. It once
    // published today's date on both documents, which made them match while
    // describing a document the app does not actually write: a completed date
    // of today beside a count of zero is the one pair that gives a pause away,
    // and it is the app, not any rule, that has to keep them apart.
    expect(
      paused.lastCompletedDate === DAY && paused.todayCompleted === 0,
    ).toBe(false);
    expect(paused.lastCompletedDate).toBe(DAY_BEFORE);
  });
});
