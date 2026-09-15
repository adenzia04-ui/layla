/**
 * Round two of Friends: jumuah/{uid}, which masjid this Friday.
 *
 * The one document where a friend reads typed text that is not a name,
 * held to the forty characters a name gets. Written by the owner, read by
 * the owner and by anyone on the owner's list, never listed.
 */
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  getDoc,
  getDocs,
  setDoc,
  setLogLevel,
  Timestamp,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';

import {
  db,
  fullAccount,
  guestAccount,
  jumuahDoc,
  jumuahRef,
  makeTestEnv,
  seedJumuah,
  seedListEntry,
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
  test('1. a masjid of forty-one characters is refused', async () => {
    const d = db(fullAccount(env, ME));
    const j = jumuahRef(d, ME);

    // Forty is a name; forty-one is the start of a paragraph.
    await assertFails(setDoc(j, jumuahDoc({ masjid: 'x'.repeat(41) })));
    await assertFails(setDoc(j, jumuahDoc({ masjid: '' })));
    await assertFails(setDoc(j, jumuahDoc({ masjid: 42 })));
  });

  test('2. a stranger cannot read it, and nobody can list the collection', async () => {
    await seedJumuah(env, ME);

    const stranger = db(fullAccount(env, STRANGER));
    await assertFails(getDoc(jumuahRef(stranger, ME)));
    await assertFails(getDocs(collection(stranger, 'jumuah')));

    // Not even the owner lists: there is no "everyone's Friday" screen.
    const me = db(fullAccount(env, ME));
    await assertFails(getDocs(collection(me, 'jumuah')));
  });

  test('3. a date that is not a day id is refused', async () => {
    const d = db(fullAccount(env, ME));
    const j = jumuahRef(d, ME);

    await assertFails(setDoc(j, jumuahDoc({ date: 'Friday' })));
    await assertFails(setDoc(j, jumuahDoc({ date: '2026-9-18' })));
    await assertFails(setDoc(j, jumuahDoc({ date: 20260918 })));
  });

  test('4. a client clock, or no clock, is refused', async () => {
    const d = db(fullAccount(env, ME));
    const j = jumuahRef(d, ME);

    await assertFails(
      setDoc(
        j,
        jumuahDoc({
          updatedAt: Timestamp.fromDate(new Date('2030-01-01T00:00:00Z')),
        }),
      ),
    );
    const noClock = jumuahDoc();
    delete noClock.updatedAt;
    await assertFails(setDoc(j, noClock));
  });

  test('5. a fourth key is refused', async () => {
    const d = db(fullAccount(env, ME));

    await assertFails(
      setDoc(jumuahRef(d, ME), jumuahDoc({ note: 'after Asr, come early' })),
    );
  });

  test('6. nobody can write somebody else’s Friday', async () => {
    await seedListEntry(env, ME, THEM, 'Yusuf', 'XYZ789');
    const d = db(fullAccount(env, THEM));

    // A friend, who may read it, still may not write it.
    await assertFails(setDoc(jumuahRef(d, ME), jumuahDoc()));
    await assertFails(deleteDoc(jumuahRef(d, ME)));
  });

  test('7. a guest cannot set one', async () => {
    const d = db(guestAccount(env, ME));

    await assertFails(setDoc(jumuahRef(d, ME), jumuahDoc()));
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// MUST BE ALLOWED
// ═══════════════════════════════════════════════════════════════════════════
describe('the honest client', () => {
  test('a. sets this Friday’s masjid, and changes it', async () => {
    const d = db(fullAccount(env, ME));
    const j = jumuahRef(d, ME);

    await assertSucceeds(setDoc(j, jumuahDoc()));
    await assertSucceeds(setDoc(j, jumuahDoc({ masjid: 'East London Mosque' })));
    await assertSucceeds(setDoc(j, jumuahDoc({ masjid: 'x'.repeat(40) })));
    // A name in Arabic is a name.
    await assertSucceeds(setDoc(j, jumuahDoc({ masjid: 'مسجد الرحمن' })));
  });

  test('b. a friend on the owner’s list reads it', async () => {
    await seedJumuah(env, ME);
    await seedListEntry(env, ME, THEM, 'Yusuf', 'XYZ789');
    const d = db(fullAccount(env, THEM));

    const snap = await assertSucceeds(getDoc(jumuahRef(d, ME)));
    expect(snap.data().masjid).toBe('Masjid al-Rahman');
    expect(snap.data().date).toBe('2026-09-18');
  });

  test('c. the owner reads it and clears it', async () => {
    await seedJumuah(env, ME);
    const d = db(fullAccount(env, ME));

    await assertSucceeds(getDoc(jumuahRef(d, ME)));
    await assertSucceeds(deleteDoc(jumuahRef(d, ME)));
  });
});
