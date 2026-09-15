/**
 * Round two of Friends: the four owner-only fields added to users/{uid}.
 *
 * `quiet`, `milestone` and `ramadan` are copied or derived onto the
 * scoreboard by the publisher, so a shape the scoreboard would refuse has
 * to be refused on the profile first. `eidSent` is a map that has to stay
 * small. And every profile write the app made before round two must go on
 * passing exactly as it did.
 */
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  deleteField,
  getDoc,
  increment,
  serverTimestamp,
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
  milestone,
  seedUser,
  userRef,
} from './support/env.js';

const ME = 'uid_me';
const ATTACKER = 'uid_attacker';

/// The owner's own record of the month, as the first write of it looks.
function ramadanRecord(overrides = {}) {
  return {
    year: 1448,
    fasts: 0,
    fastedOn: null,
    taraweehOn: null,
    ...overrides,
  };
}

/// An eidSent map with `n` entries, "1448-1", "1448-2", "1449-1", ...
function eidSentOf(n) {
  const out = {};
  for (let i = 0; i < n; i += 1) {
    out[`${1448 + Math.floor(i / 2)}-${(i % 2) + 1}`] = true;
  }
  return out;
}

let env;

beforeAll(async () => {
  setLogLevel('error');
  env = await makeTestEnv();
});

afterAll(async () => {
  await env?.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await seedUser(env, ME, { displayName: 'Aisha' });
});

// ═══════════════════════════════════════════════════════════════════════════
// MUST BE DENIED
// ═══════════════════════════════════════════════════════════════════════════
describe('profile fields that must be refused', () => {
  test('1. a quiet that is not a bool is refused', async () => {
    const d = db(fullAccount(env, ME));

    await assertFails(updateDoc(userRef(d, ME), { quiet: 'yes' }));
    await assertFails(
      setDoc(userRef(d, ME), { quiet: 1 }, { merge: true }),
    );
  });

  test('2. a milestone with an unknown key, or the wrong shape, is refused', async () => {
    const d = db(fullAccount(env, ME));
    const u = userRef(d, ME);

    // What is refused on the scoreboard is refused here, so that the
    // publisher's copy can never be the write that fails.
    await assertFails(updateDoc(u, { milestone: milestone('streak50') }));
    await assertFails(updateDoc(u, { milestone: { key: 'streak100' } }));
    await assertFails(
      updateDoc(u, { milestone: { ...milestone(), note: 'x' } }),
    );
    await assertFails(
      updateDoc(u, { milestone: { key: 'streak100', at: '2026-09-10' } }),
    );
    await assertFails(updateDoc(u, { milestone: 'streak100' }));
  });

  test('3. a Ramadan record out of bounds is refused', async () => {
    const d = db(fullAccount(env, ME));
    const u = userRef(d, ME);

    await assertFails(updateDoc(u, { ramadan: ramadanRecord({ fasts: 31 }) }));
    await assertFails(updateDoc(u, { ramadan: ramadanRecord({ fasts: -1 }) }));
    await assertFails(updateDoc(u, { ramadan: ramadanRecord({ fasts: 1.5 }) }));
    await assertFails(updateDoc(u, { ramadan: ramadanRecord({ year: 999 }) }));
    await assertFails(updateDoc(u, { ramadan: ramadanRecord({ year: 1700 }) }));
    await assertFails(updateDoc(u, { ramadan: ramadanRecord({ year: '1448' }) }));
    await assertFails(
      updateDoc(u, { ramadan: ramadanRecord({ fastedOn: 'Friday' }) }),
    );
    await assertFails(
      updateDoc(u, { ramadan: ramadanRecord({ taraweehOn: 20270220 }) }),
    );
    await assertFails(
      updateDoc(u, { ramadan: ramadanRecord({ notes: 'tired today' }) }),
    );
    await assertFails(updateDoc(u, { ramadan: 12 }));

    // And by field, the way a day is marked: past thirty is still past
    // thirty when it gets there one increment at a time.
    await assertSucceeds(updateDoc(u, { ramadan: ramadanRecord({ fasts: 30 }) }));
    await assertFails(updateDoc(u, { 'ramadan.fasts': increment(1) }));
  });

  test('4. an eidSent that is not a small map of trues is refused', async () => {
    const d = db(fullAccount(env, ME));
    const u = userRef(d, ME);

    await assertFails(updateDoc(u, { eidSent: { '1448-1': false } }));
    await assertFails(updateDoc(u, { eidSent: { '1448-1': 'sent' } }));
    await assertFails(updateDoc(u, { eidSent: { '1448-1': true, '1448-2': 1 } }));
    await assertFails(updateDoc(u, { eidSent: '1448-1' }));
    await assertFails(updateDoc(u, { eidSent: ['1448-1'] }));
    // Two hundred is a century of Eids; two hundred and one is a map with
    // no ceiling.
    await assertFails(updateDoc(u, { eidSent: eidSentOf(201) }));
  });

  test('5. nobody else can put any of them on somebody’s profile', async () => {
    const d = db(fullAccount(env, ATTACKER));
    const u = userRef(d, ME);

    await assertFails(updateDoc(u, { quiet: true }));
    await assertFails(updateDoc(u, { milestone: milestone() }));
    await assertFails(updateDoc(u, { ramadan: ramadanRecord() }));
    await assertFails(updateDoc(u, { eidSent: { '1448-1': true } }));
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// MUST BE ALLOWED
// ═══════════════════════════════════════════════════════════════════════════
describe('the honest client', () => {
  test('a. flips quiet on and off, and clears it', async () => {
    const d = db(fullAccount(env, ME));
    const u = userRef(d, ME);

    await assertSucceeds(setDoc(u, { quiet: true }, { merge: true }));
    await assertSucceeds(updateDoc(u, { quiet: false }));
    await assertSucceeds(updateDoc(u, { quiet: null }));
    await assertSucceeds(updateDoc(u, { quiet: deleteField() }));
  });

  test('b. records a milestone, and the next one', async () => {
    const d = db(fullAccount(env, ME));
    const u = userRef(d, ME);

    await assertSucceeds(updateDoc(u, { milestone: milestone('tahajjud1') }));
    await assertSucceeds(updateDoc(u, { milestone: milestone('streak100') }));
    // Stamped with the server clock at the moment it was crossed is fine
    // too: any timestamp is a timestamp.
    await assertSucceeds(
      updateDoc(u, { milestone: { key: 'prayers1000', at: serverTimestamp() } }),
    );
    const snap = await assertSucceeds(getDoc(u));
    expect(snap.data().milestone.key).toBe('prayers1000');
  });

  test('c. keeps the Ramadan record, whole and by field', async () => {
    const d = db(fullAccount(env, ME));
    const u = userRef(d, ME);

    // The first day of the month writes the record whole…
    await assertSucceeds(setDoc(u, { ramadan: ramadanRecord() }, { merge: true }));
    // …and every day after marks a field.
    await assertSucceeds(
      updateDoc(u, {
        'ramadan.fastedOn': '2027-02-20',
        'ramadan.fasts': increment(1),
      }),
    );
    await assertSucceeds(updateDoc(u, { 'ramadan.taraweehOn': '2027-02-20' }));
    await assertSucceeds(updateDoc(u, { 'ramadan.fastedOn': null }));
    const snap = await assertSucceeds(getDoc(u));
    expect(snap.data().ramadan.fasts).toBe(1);

    // A record that starts from a single field update is not refused for
    // the keys it does not have yet.
    await assertSucceeds(updateDoc(u, { ramadan: deleteField() }));
    await assertSucceeds(updateDoc(u, { 'ramadan.fasts': 1 }));
    await assertSucceeds(updateDoc(u, { ramadan: null }));
  });

  test('d. marks an Eid as sent, and the next one', async () => {
    const d = db(fullAccount(env, ME));
    const u = userRef(d, ME);

    await assertSucceeds(
      setDoc(u, { eidSent: { '1448-1': true } }, { merge: true }),
    );
    await assertSucceeds(updateDoc(u, { 'eidSent.1448-2': true }));
    await assertSucceeds(updateDoc(u, { eidSent: eidSentOf(200) }));
    await assertSucceeds(updateDoc(u, { eidSent: {} }));
  });

  test('e. every profile write from before round two is untouched', async () => {
    const d = db(fullAccount(env, ME));
    const u = userRef(d, ME);

    // The seed write at sign-up, and the field writes the app makes after.
    await assertSucceeds(
      setDoc(u, {
        displayName: 'Aisha',
        email: 'aisha@example.com',
        createdAt: serverTimestamp(),
        settings: { madhab: 'hanafi', method: 'mwl' },
        gender: 'sister',
      }),
    );
    await assertSucceeds(updateDoc(u, { displayName: 'Aisha K' }));
    await assertSucceeds(
      updateDoc(u, { 'settings.method': 'isna', 'settings.adhan': true }),
    );
    await assertSucceeds(
      updateDoc(u, { location: { lat: 51.5, lng: -0.12, city: 'London' } }),
    );
    await assertSucceeds(setDoc(u, { friendCode: 'ABC234' }, { merge: true }));
    await assertSucceeds(
      updateDoc(u, {
        stats: { streak: 3, longestStreak: 12, totalPrayers: 900 },
      }),
    );
    await assertSucceeds(updateDoc(u, { cycle: { startedOn: '2026-09-12' } }));
    await assertSucceeds(updateDoc(u, { cycle: null }));
  });

  test('f. a guest can go quiet on their own profile', async () => {
    // Owner-only, not full-account-only: the profile is private, and a
    // guest's own switch on their own document is nobody else's business.
    const d = db(guestAccount(env, ME));

    await assertSucceeds(updateDoc(userRef(d, ME), { quiet: true }));
  });
});
