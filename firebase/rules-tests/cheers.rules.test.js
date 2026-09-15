/**
 * Round two of Friends: cheers/{toUid}/from/{fromUid}, "MashaAllah" on a
 * friend's milestone.
 *
 * A cheer is a tap, not a message: the milestone's key and the server's
 * clock, nothing else, from someone on the recipient's list. Only the
 * recipient reads them, as a count.
 */
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  getDoc,
  getDocs,
  query,
  setDoc,
  setLogLevel,
  Timestamp,
  where,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';

import {
  cheerDoc,
  cheerRef,
  cheersColl,
  db,
  fullAccount,
  guestAccount,
  makeTestEnv,
  seedCheer,
  seedFriends,
  seedListEntry,
} from './support/env.js';

const ME = 'uid_me';
const THEM = 'uid_them';
const OTHER = 'uid_other';
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
  test('1. a non-friend cannot cheer', async () => {
    const d = db(fullAccount(env, STRANGER));

    // Nobody on either list.
    await assertFails(setDoc(cheerRef(d, THEM, STRANGER), cheerDoc()));

    // The stranger has THEM on their OWN list — a leftover from a
    // friendship THEM ended — which is not the list the rule checks: the
    // recipient's list, the one the recipient's code guards.
    await seedListEntry(env, STRANGER, THEM, 'Them', 'XYZ789');
    await assertFails(setDoc(cheerRef(d, THEM, STRANGER), cheerDoc()));
  });

  test('2. a cheer with a fourth key — or any third — is refused', async () => {
    await seedFriends(env, ME, THEM);
    const d = db(fullAccount(env, ME));

    // The closed key list is what keeps a tap from becoming a message.
    await assertFails(
      setDoc(
        cheerRef(d, THEM, ME),
        cheerDoc('streak100', { note: 'mashaAllah', text: 'call me' }),
      ),
    );
    await assertFails(
      setDoc(cheerRef(d, THEM, ME), cheerDoc('streak100', { note: 'hi' })),
    );
  });

  test('3. a cheer on a milestone that does not exist is refused', async () => {
    await seedFriends(env, ME, THEM);
    const d = db(fullAccount(env, ME));

    await assertFails(setDoc(cheerRef(d, THEM, ME), cheerDoc('streak50')));
    await assertFails(setDoc(cheerRef(d, THEM, ME), cheerDoc(42)));
    await assertFails(setDoc(cheerRef(d, THEM, ME), { at: cheerDoc().at }));
  });

  test('4. a cheer cannot carry a client clock, or no clock', async () => {
    await seedFriends(env, ME, THEM);
    const d = db(fullAccount(env, ME));

    await assertFails(
      setDoc(
        cheerRef(d, THEM, ME),
        cheerDoc('streak100', {
          at: Timestamp.fromDate(new Date('2030-01-01T00:00:00Z')),
        }),
      ),
    );
    await assertFails(setDoc(cheerRef(d, THEM, ME), { milestone: 'streak100' }));
  });

  test('5. a cheer cannot be left in somebody else’s name', async () => {
    await seedFriends(env, ME, THEM);
    await seedFriends(env, OTHER, THEM);
    const d = db(fullAccount(env, ME));

    // OTHER really is a friend of THEM; ME still cannot sign as them.
    await assertFails(setDoc(cheerRef(d, THEM, OTHER), cheerDoc()));
  });

  test('6. a guest cannot cheer, even from the list', async () => {
    await seedFriends(env, ME, THEM);
    const d = db(guestAccount(env, ME));

    await assertFails(setDoc(cheerRef(d, THEM, ME), cheerDoc()));
  });

  test('7. nobody but the recipient reads cheers', async () => {
    await seedFriends(env, ME, THEM);
    await seedCheer(env, THEM, ME);

    // Not the friend who left it…
    const me = db(fullAccount(env, ME));
    await assertFails(getDoc(cheerRef(me, THEM, ME)));
    await assertFails(getDocs(cheersColl(me, THEM)));

    // …and not a stranger, by id or by listing.
    const stranger = db(fullAccount(env, STRANGER));
    await assertFails(getDoc(cheerRef(stranger, THEM, ME)));
    await assertFails(getDocs(cheersColl(stranger, THEM)));
  });

  test('8. nobody else can take a cheer away', async () => {
    await seedFriends(env, ME, THEM);
    await seedFriends(env, OTHER, THEM);
    await seedCheer(env, THEM, ME);

    await assertFails(deleteDoc(cheerRef(db(fullAccount(env, STRANGER)), THEM, ME)));
    // Not even another friend of the recipient.
    await assertFails(deleteDoc(cheerRef(db(fullAccount(env, OTHER)), THEM, ME)));
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// MUST BE ALLOWED
// ═══════════════════════════════════════════════════════════════════════════
describe('the honest client', () => {
  test('a. cheers a friend’s milestone, and cheering again overwrites', async () => {
    await seedFriends(env, ME, THEM);
    const d = db(fullAccount(env, ME));

    await assertSucceeds(setDoc(cheerRef(d, THEM, ME), cheerDoc('streak100')));
    // The document id is the friend, so the next milestone's cheer lands
    // on the same document — an update, under the same rule.
    await assertSucceeds(setDoc(cheerRef(d, THEM, ME), cheerDoc('prayers1000')));
  });

  test('b. the recipient counts them', async () => {
    await seedFriends(env, ME, THEM);
    await seedFriends(env, OTHER, THEM);
    await seedCheer(env, THEM, ME, 'streak100');
    await seedCheer(env, THEM, OTHER, 'streak100');
    const d = db(fullAccount(env, THEM));

    const all = await assertSucceeds(getDocs(cheersColl(d, THEM)));
    expect(all.size).toBe(2);
    // "2 friends said MashaAllah" on the latest milestone only.
    const onThis = await assertSucceeds(
      getDocs(query(cheersColl(d, THEM), where('milestone', '==', 'streak100'))),
    );
    expect(onThis.size).toBe(2);
    await assertSucceeds(getDoc(cheerRef(d, THEM, ME)));
  });

  test('c. the recipient clears one, and a friend takes their own back', async () => {
    await seedFriends(env, ME, THEM);
    await seedFriends(env, OTHER, THEM);
    await seedCheer(env, THEM, ME);
    await seedCheer(env, THEM, OTHER);

    await assertSucceeds(deleteDoc(cheerRef(db(fullAccount(env, THEM)), THEM, ME)));
    await assertSucceeds(deleteDoc(cheerRef(db(fullAccount(env, OTHER)), THEM, OTHER)));
  });
});
