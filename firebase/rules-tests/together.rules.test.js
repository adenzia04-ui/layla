/**
 * Round two of Friends: friends/{uid}/meta/{friendUid}, the baseline for
 * "N prayers together".
 *
 * The owner's own bookkeeping: the two totals as they stood the first time
 * their phone saw this friend's scoreboard. Nobody else — not the friend it
 * is about — can read or write it.
 */
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  getDoc,
  getDocs,
  setDoc,
  setLogLevel,
  Timestamp,
  updateDoc,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';

import {
  db,
  fullAccount,
  guestAccount,
  makeTestEnv,
  metaColl,
  metaDoc,
  metaRef,
  seedFriends,
  seedMeta,
} from './support/env.js';

const ME = 'uid_me';
const THEM = 'uid_them';
const STRANGER = 'uid_stranger';

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
});

// ═══════════════════════════════════════════════════════════════════════════
// MUST BE DENIED
// ═══════════════════════════════════════════════════════════════════════════
describe('attacks', () => {
  test('1. a friend cannot read friends/{uid}/meta', async () => {
    await seedFriends(env, ME, THEM);
    await seedMeta(env, ME, THEM);

    // The friend it is about, by id and by listing…
    const them = db(fullAccount(env, THEM));
    await assertFails(getDoc(metaRef(them, ME, THEM)));
    await assertFails(getDocs(metaColl(them, ME)));

    // …and anyone else.
    const stranger = db(fullAccount(env, STRANGER));
    await assertFails(getDoc(metaRef(stranger, ME, THEM)));
    await assertFails(getDocs(metaColl(stranger, ME)));
  });

  test('2. a friend cannot write it', async () => {
    await seedFriends(env, ME, THEM);
    await seedMeta(env, ME, THEM);
    const d = db(fullAccount(env, THEM));

    // Moving somebody's baseline moves the number on their card.
    await assertFails(setDoc(metaRef(d, ME, THEM), metaDoc()));
    await assertFails(updateDoc(metaRef(d, ME, THEM), { theirStartTotal: 0 }));
    await assertFails(deleteDoc(metaRef(d, ME, THEM)));
  });

  test('3. a baseline out of shape is refused', async () => {
    const d = db(fullAccount(env, ME));
    const m = metaRef(d, ME, THEM);

    await assertFails(setDoc(m, metaDoc({ myStartTotal: -1 })));
    await assertFails(setDoc(m, metaDoc({ myStartTotal: 200001 })));
    await assertFails(setDoc(m, metaDoc({ myStartTotal: 'nine' })));
    await assertFails(setDoc(m, metaDoc({ myStartTotal: 9.5 })));
    await assertFails(setDoc(m, metaDoc({ theirStartTotal: -1 })));
    await assertFails(setDoc(m, metaDoc({ theirStartTotal: 200001 })));
    await assertFails(setDoc(m, metaDoc({ at: 'yesterday' })));
    await assertFails(setDoc(m, metaDoc({ at: 1757480400 })));
    await assertFails(setDoc(m, metaDoc({ note: 'since Ramadan' })));

    const noClock = metaDoc();
    delete noClock.at;
    await assertFails(setDoc(m, noClock));
    const half = metaDoc();
    delete half.theirStartTotal;
    await assertFails(setDoc(m, half));
  });

  test('4. a guest cannot write one', async () => {
    const d = db(guestAccount(env, ME));

    await assertFails(setDoc(metaRef(d, ME, THEM), metaDoc()));
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// MUST BE ALLOWED
// ═══════════════════════════════════════════════════════════════════════════
describe('the honest client', () => {
  test('a. writes the baseline, with either clock', async () => {
    await seedFriends(env, ME, THEM);
    const d = db(fullAccount(env, ME));

    await assertSucceeds(setDoc(metaRef(d, ME, THEM), metaDoc()));
    // Nobody but the owner reads this document, so a timestamp from the
    // phone's own clock misleads nobody but its owner.
    await assertSucceeds(
      setDoc(
        metaRef(d, ME, STRANGER),
        metaDoc({ at: Timestamp.fromDate(new Date('2026-09-14T05:00:00Z')) }),
      ),
    );
    await assertSucceeds(
      setDoc(
        metaRef(d, ME, 'uid_other'),
        metaDoc({ myStartTotal: 0, theirStartTotal: 200000 }),
      ),
    );
  });

  test('b. reads it back, one and all', async () => {
    await seedFriends(env, ME, THEM);
    await seedMeta(env, ME, THEM);
    await seedMeta(env, ME, STRANGER, { theirStartTotal: 5 });
    const d = db(fullAccount(env, ME));

    const one = await assertSucceeds(getDoc(metaRef(d, ME, THEM)));
    expect(one.data().theirStartTotal).toBe(1200);
    const all = await assertSucceeds(getDocs(metaColl(d, ME)));
    expect(all.size).toBe(2);
  });

  test('c. rewrites it, and removes it with the friendship', async () => {
    await seedFriends(env, ME, THEM);
    await seedMeta(env, ME, THEM);
    const d = db(fullAccount(env, ME));

    await assertSucceeds(setDoc(metaRef(d, ME, THEM), metaDoc({ myStartTotal: 950 })));
    await assertSucceeds(deleteDoc(metaRef(d, ME, THEM)));
  });
});
