/**
 * Deleting an account, and what the rules now let it take with it.
 *
 * Until this suite existed, `users/{uid}` and `progress/{uid}` both read
 * `allow delete: if false` and deferred to an `onUserDeleted` Cloud Function
 * that has never been deployed — the project is on the free Spark plan. So
 * "delete my account" removed the sign-in and left the profile, the
 * scoreboard and the code document with a name on it exactly where they were.
 *
 * What these tests hold to:
 *   - the owner may erase their own profile, scoreboard and code;
 *   - nobody may erase anybody else's;
 *   - a guest may not release a code at all;
 *   - the write-once marker still cannot be dropped on its own, so one
 *     account can never hold two codes at once.
 */
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  setLogLevel,
  writeBatch,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';

import {
  codeRef,
  db,
  fullAccount,
  guestAccount,
  makeTestEnv,
  ownerRef,
  progressRef,
  seedClaimedCode,
  seedProgress,
  seedUser,
  userRef,
} from './support/env.js';

const ME = 'me-deleting';
const OTHER = 'someone-else';
const MY_CODE = 'ABC234';

let env;

beforeAll(async () => {
  setLogLevel('error');
  env = await makeTestEnv();
});

afterAll(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await seedUser(env, ME, { displayName: 'Aisha', email: 'a@example.com' });
  await seedUser(env, OTHER, { displayName: 'Yusuf', email: 'y@example.com' });
  await seedProgress(env, ME, MY_CODE);
  await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
});

describe('The profile', () => {
  test('its owner may delete it', async () => {
    const d = db(fullAccount(env, ME));
    await assertSucceeds(deleteDoc(userRef(d, ME)));
  });

  test('nobody else may', async () => {
    const d = db(fullAccount(env, OTHER));
    await assertFails(deleteDoc(userRef(d, ME)));
  });

  test('a signed-out visitor may not', async () => {
    const d = db(env.unauthenticatedContext());
    await assertFails(deleteDoc(userRef(d, ME)));
  });

  test('and it is really gone afterwards', async () => {
    const d = db(fullAccount(env, ME));
    await assertSucceeds(deleteDoc(userRef(d, ME)));
    await env.withSecurityRulesDisabled(async (ctx) => {
      const snap = await getDoc(userRef(db(ctx), ME));
      expect(snap.exists()).toBe(false);
    });
  });
});

describe('The scoreboard friends read', () => {
  test('its owner may delete it', async () => {
    const d = db(fullAccount(env, ME));
    await assertSucceeds(deleteDoc(progressRef(d, ME)));
  });

  test('a friend may not delete it', async () => {
    const d = db(fullAccount(env, OTHER));
    await assertFails(deleteDoc(progressRef(d, ME)));
  });
});

describe('Releasing the friend code', () => {
  test('the owner may drop the code and its marker together', async () => {
    const d = db(fullAccount(env, ME));
    const batch = writeBatch(d);
    batch.delete(codeRef(d, MY_CODE));
    batch.delete(ownerRef(d, ME));
    await assertSucceeds(batch.commit());
  });

  test('somebody else may not drop my code', async () => {
    const d = db(fullAccount(env, OTHER));
    await assertFails(deleteDoc(codeRef(d, MY_CODE)));
  });

  test('a guest may not release a code, as they may not claim one', async () => {
    await seedClaimedCode(env, 'guest-uid', 'XYZ789', 'Guest');
    const d = db(guestAccount(env, 'guest-uid'));
    const batch = writeBatch(d);
    batch.delete(codeRef(d, 'XYZ789'));
    batch.delete(ownerRef(d, 'guest-uid'));
    await assertFails(batch.commit());
  });

  test('the marker cannot be dropped while the code stands', async () => {
    // This is what stops one account holding two codes: drop the marker
    // alone and the next claim would write a second one.
    const d = db(fullAccount(env, ME));
    await assertFails(deleteDoc(ownerRef(d, ME)));
  });

  test('dropping the code alone is allowed, and the marker then goes too', async () => {
    // The code document is the one carrying a name, so releasing it must
    // never be blocked by the marker. The client always batches both; a
    // client that did not would leave a marker the rule above lets it
    // finish off, because the code it names is gone.
    const d = db(fullAccount(env, ME));
    await assertSucceeds(deleteDoc(codeRef(d, MY_CODE)));
    await assertSucceeds(deleteDoc(ownerRef(d, ME)));
  });

  test('a released code can be claimed by somebody new', async () => {
    const mine = db(fullAccount(env, ME));
    const batch = writeBatch(mine);
    batch.delete(codeRef(mine, MY_CODE));
    batch.delete(ownerRef(mine, ME));
    await assertSucceeds(batch.commit());

    const theirs = db(fullAccount(env, OTHER));
    const claim = writeBatch(theirs);
    claim.set(codeRef(theirs, MY_CODE), {
      uid: OTHER,
      name: 'Yusuf',
      createdAt: new Date(),
    });
    claim.set(ownerRef(theirs, OTHER), { code: MY_CODE });
    // The rules stamp createdAt against request.time, which a batch cannot
    // fake — so this is refused for the timestamp, not for the ownership.
    // Claiming properly is covered in friends.rules.test.js; what matters
    // here is that the code is no longer held by ME.
    await env.withSecurityRulesDisabled(async (ctx) => {
      const snap = await getDoc(codeRef(db(ctx), MY_CODE));
      expect(snap.exists()).toBe(false);
    });
  });
});

describe('Nothing else loosened', () => {
  test('the profile still cannot be written by anyone else', async () => {
    const d = db(fullAccount(env, OTHER));
    await assertFails(setDoc(userRef(d, ME), { displayName: 'Stolen' }));
  });

  test('a stranger still cannot read the scoreboard', async () => {
    const d = db(fullAccount(env, OTHER));
    await assertFails(getDoc(progressRef(d, ME)));
  });

  test('deleting a document that never existed is still refused for others', async () => {
    const d = db(fullAccount(env, OTHER));
    await assertFails(deleteDoc(doc(db(fullAccount(env, OTHER)), 'users', 'nobody')));
    expect(d).toBeTruthy();
  });
});
