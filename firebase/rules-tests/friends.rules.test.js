/**
 * Executable security-rules tests for the Layla Pro Friends feature.
 *
 * Firebase is on the Spark plan and no Cloud Functions are deployed, so
 * firebase/firestore.rules is the ONLY server-side enforcement there is.
 * Everything below runs against the real rules file, read off disk.
 *
 * Run with:   npm run emu     (starts the Firestore emulator, runs, shuts down)
 * or, against an emulator you already have running on 127.0.0.1:8080:
 *             npm test
 */
import {
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  deleteField,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  setLogLevel,
  Timestamp,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';

import {
  blockRef,
  codeRef,
  db,
  friendEntry,
  fullAccount,
  guestAccount,
  listRef,
  makeTestEnv,
  ownerRef,
  progressDoc,
  progressRef,
  seedBlock,
  seedClaimedCode,
  seedListEntry,
  seedProgress,
  seedUser,
  upgradedGuest,
  userRef,
} from './support/env.js';

// The people in these tests.
const ME = 'uid_me';
const THEM = 'uid_them';
const ATTACKER = 'uid_attacker';
const VICTIM = 'uid_victim';
const STRANGER = 'uid_stranger';

// Codes in the FriendCode alphabet — 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
// which has no I, O, 0 or 1 in it.
const MY_CODE = 'ABC234';
const THEIR_CODE = 'XYZ789';
const ATTACKER_CODE = 'TUV567';
const VICTIM_CODE = 'QRS345';
const STRANGER_CODE = 'GHJ456';

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
// MUST BE DENIED — if any of these passes, it is a hole in the rules.
// ═══════════════════════════════════════════════════════════════════════════
describe('attacks', () => {
  test('1. a full account cannot list friend_codes', async () => {
    await seedClaimedCode(env, VICTIM, VICTIM_CODE, 'Victim');
    const d = db(fullAccount(env, ATTACKER));

    // Harvesting the collection would turn "the code is the only way in" into
    // "every code is one query away".
    await assertFails(getDocs(collection(d, 'friend_codes')));
  });

  test('2. a stranger cannot read a scoreboard they are not on the list for', async () => {
    await seedClaimedCode(env, VICTIM, VICTIM_CODE, 'Victim');
    await seedProgress(env, VICTIM, VICTIM_CODE);
    const d = db(fullAccount(env, ATTACKER));

    await assertFails(getDoc(progressRef(d, VICTIM)));
  });

  test('3. cannot write myself onto a victim’s list on its own', async () => {
    await seedClaimedCode(env, ATTACKER, ATTACKER_CODE, 'Attacker');
    await seedClaimedCode(env, VICTIM, VICTIM_CODE, 'Victim');
    const d = db(fullAccount(env, ATTACKER));

    // No mirror entry in this write, so `existsAfter` on my own list finds
    // nothing: landing on someone's list has to be paid for with their code.
    await assertFails(
      setDoc(
        listRef(d, VICTIM, ATTACKER),
        friendEntry('Attacker', ATTACKER_CODE),
      ),
    );
  });

  test('4. cannot write both sides with a code that belongs to a third party', async () => {
    await seedClaimedCode(env, ATTACKER, ATTACKER_CODE, 'Attacker');
    await seedClaimedCode(env, VICTIM, VICTIM_CODE, 'Victim');
    await seedClaimedCode(env, STRANGER, STRANGER_CODE, 'Stranger');
    const d = db(fullAccount(env, ATTACKER));

    // The batch is shaped exactly like an honest add, but the code on my side
    // is the STRANGER's, not the victim's — the one code I was never given.
    const batch = writeBatch(d);
    batch.set(
      listRef(d, ATTACKER, VICTIM),
      friendEntry('Victim', STRANGER_CODE),
    );
    batch.set(
      listRef(d, VICTIM, ATTACKER),
      friendEntry('Attacker', ATTACKER_CODE),
    );
    await assertFails(batch.commit());
  });

  test('5. cannot claim a second friend code once the marker exists', async () => {
    await seedClaimedCode(env, ATTACKER, ATTACKER_CODE, 'Attacker');
    await seedUser(env, ATTACKER, {
      displayName: 'Attacker',
      friendCode: ATTACKER_CODE,
    });
    const d = db(fullAccount(env, ATTACKER));
    const second = 'MNP234';

    // (a) A fresh code on its own: `getAfter` on the marker still sees the
    // first code, so the ids do not match.
    await assertFails(
      setDoc(codeRef(d, second), {
        uid: ATTACKER,
        name: 'Attacker',
        createdAt: serverTimestamp(),
      }),
    );

    // (b) Code and a new marker together, the way the first claim is written.
    // The marker is create-only and one already exists, so the batch dies.
    const batch = writeBatch(d);
    batch.set(codeRef(d, second), {
      uid: ATTACKER,
      name: 'Attacker',
      createdAt: serverTimestamp(),
    });
    batch.set(ownerRef(d, ATTACKER), { code: second });
    await assertFails(batch.commit());

    // (c) The profile field is mine to delete — and deleting it changes
    // nothing, which is the entire reason the marker is not the profile.
    await assertSucceeds(
      updateDoc(userRef(d, ATTACKER), { friendCode: deleteField() }),
    );
    const after = writeBatch(d);
    after.set(codeRef(d, second), {
      uid: ATTACKER,
      name: 'Attacker',
      createdAt: serverTimestamp(),
    });
    after.set(ownerRef(d, ATTACKER), { code: second });
    await assertFails(after.commit());

    // And the marker itself can never be unwritten.
    await assertFails(deleteDoc(ownerRef(d, ATTACKER)));
    await assertFails(updateDoc(ownerRef(d, ATTACKER), { code: second }));
  });

  test('6. an existing friend_codes document can be neither updated nor deleted', async () => {
    await seedClaimedCode(env, VICTIM, VICTIM_CODE, 'Victim');
    const attacker = db(fullAccount(env, ATTACKER));
    const owner = db(fullAccount(env, VICTIM));

    // A stranger must not be able to point a handed-out code at themselves,
    // or free it up to be re-squatted.
    await assertFails(
      updateDoc(codeRef(attacker, VICTIM_CODE), { uid: ATTACKER }),
    );
    await assertFails(deleteDoc(codeRef(attacker, VICTIM_CODE)));

    // Not even the owner: a code never changes hands.
    await assertFails(updateDoc(codeRef(owner, VICTIM_CODE), { name: 'New' }));
    await assertFails(deleteDoc(codeRef(owner, VICTIM_CODE)));
  });

  test('7. a friend code id must be six characters of the alphabet', async () => {
    const d = db(fullAccount(env, ATTACKER));
    // Near-misses of a real code, filed under the victim's name, are what a
    // squatter wants: 'ABC-234' mistyped lands on whatever they parked there.
    const ids = [
      'abc234', // lowercase
      'ABC-23', // punctuation
      'ABC2345', // seven
      'ABC23', // five
      'ABC0O1', // the four characters the alphabet leaves out
    ];

    for (const id of ids) {
      // The marker goes in the same batch, so `getAfter` is satisfied and the
      // id itself is the only thing left to refuse. (For the five- and
      // seven-character ids the marker's own `size() == 6` refuses them too —
      // belt and braces, both rules say no.)
      const batch = writeBatch(d);
      batch.set(codeRef(d, id), {
        uid: ATTACKER,
        name: 'Attacker',
        createdAt: serverTimestamp(),
      });
      batch.set(ownerRef(d, ATTACKER), { code: id });
      await assertFails(batch.commit(), `id "${id}" should be refused`);
    }
  });

  test('8. someone who was removed cannot add themselves back', async () => {
    await seedClaimedCode(env, ATTACKER, ATTACKER_CODE, 'Attacker');
    await seedClaimedCode(env, VICTIM, VICTIM_CODE, 'Victim');
    // The victim removed them, which wrote this block.
    await seedBlock(env, VICTIM, ATTACKER);
    const d = db(fullAccount(env, ATTACKER));

    // They still hold the victim's code — a friend has seen it — so the whole
    // honest add is available to them. The block is what stops it.
    const batch = writeBatch(d);
    batch.delete(blockRef(d, ATTACKER, VICTIM));
    batch.set(listRef(d, ATTACKER, VICTIM), friendEntry('Victim', VICTIM_CODE));
    batch.set(
      listRef(d, VICTIM, ATTACKER),
      friendEntry('Attacker', ATTACKER_CODE),
    );
    await assertFails(batch.commit());

    // Nor can they lift the block themselves — it is the victim's document.
    await assertFails(deleteDoc(blockRef(d, VICTIM, ATTACKER)));
  });

  test('9. progress cannot claim a longest streak behind the current one', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));

    await assertFails(
      setDoc(
        progressRef(d, ME),
        progressDoc(MY_CODE, { streak: 30, longestStreak: 29 }),
      ),
    );
  });

  test('10. progress counters cannot go past their ceilings', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));
    const p = progressRef(d, ME);

    await assertFails(
      setDoc(p, progressDoc(MY_CODE, { streak: 40001, longestStreak: 40001 })),
    );
    await assertFails(setDoc(p, progressDoc(MY_CODE, { totalPrayers: 200001 })));
    await assertFails(setDoc(p, progressDoc(MY_CODE, { totalTahajjud: 40001 })));
    await assertFails(setDoc(p, progressDoc(MY_CODE, { todayCompleted: 6 })));
  });

  test('11. progress cannot carry a key outside the published set', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));

    // Whatever it holds, a friend's phone would read it — a scoreboard is not
    // a place to smuggle a location or an email into.
    await assertFails(
      setDoc(
        progressRef(d, ME),
        progressDoc(MY_CODE, { lat: 51.5, lng: -0.12 }),
      ),
    );
  });

  test('12. progress cannot carry a code that belongs to somebody else', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedClaimedCode(env, THEM, THEIR_CODE, 'Yusuf');
    const d = db(fullAccount(env, ME));

    await assertFails(setDoc(progressRef(d, ME), progressDoc(THEIR_CODE)));
  });

  test('13. a list entry cannot be stamped with a client clock', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedClaimedCode(env, THEM, THEIR_CODE, 'Yusuf');
    const d = db(fullAccount(env, ME));

    // A phone that picks its own `since` picks its own place in a list that
    // orders by it, for ever.
    await assertFails(
      setDoc(
        listRef(d, ME, THEM),
        friendEntry('Yusuf', THEIR_CODE, {
          since: Timestamp.fromDate(new Date('2030-01-01T00:00:00Z')),
        }),
      ),
    );
  });

  test('14. a list entry cannot have an empty or overlong name', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedClaimedCode(env, THEM, THEIR_CODE, 'Yusuf');
    const d = db(fullAccount(env, ME));

    await assertFails(
      setDoc(listRef(d, ME, THEM), friendEntry('', THEIR_CODE)),
    );
    await assertFails(
      setDoc(listRef(d, ME, THEM), friendEntry('x'.repeat(41), THEIR_CODE)),
    );
  });

  test('15a. a guest cannot claim a code, add a friend, or publish progress', async () => {
    // Everything a guest would need is in place, so the only thing refusing
    // them is that they are a guest.
    await seedClaimedCode(env, ATTACKER, ATTACKER_CODE, 'Guest');
    await seedClaimedCode(env, THEM, THEIR_CODE, 'Yusuf');
    const d = db(guestAccount(env, ATTACKER));

    const claim = writeBatch(d);
    claim.set(codeRef(d, 'WXY234'), {
      uid: ATTACKER,
      name: 'Guest',
      createdAt: serverTimestamp(),
    });
    claim.set(ownerRef(d, ATTACKER), { code: 'WXY234' });
    await assertFails(claim.commit());

    await assertFails(
      setDoc(listRef(d, ATTACKER, THEM), friendEntry('Yusuf', THEIR_CODE)),
    );

    await assertFails(
      setDoc(progressRef(d, ATTACKER), progressDoc(ATTACKER_CODE)),
    );
  });

  test('15b. a signed-out client cannot read a code or a scoreboard', async () => {
    await seedClaimedCode(env, VICTIM, VICTIM_CODE, 'Victim');
    await seedProgress(env, VICTIM, VICTIM_CODE);
    const d = db(env.unauthenticatedContext());

    await assertFails(getDoc(codeRef(d, VICTIM_CODE)));
    await assertFails(getDoc(progressRef(d, VICTIM)));
  });

  test('15c. a signed-out client cannot write anything at all', async () => {
    await seedClaimedCode(env, VICTIM, VICTIM_CODE, 'Victim');
    const d = db(env.unauthenticatedContext());

    // Every write rule in the Friends block opens with isFullAccount() or
    // isOwner(), both of which start at signedIn() — but "denied because the
    // helper happens to short-circuit" is a fact worth an assertion of its
    // own, since a later edit could reorder a clause and leave a null
    // request.auth reaching a check that does not look at it.

    // A code claim, the whole batch the honest client sends.
    const claim = writeBatch(d);
    claim.set(codeRef(d, 'WXY234'), {
      uid: STRANGER,
      name: 'Nobody',
      createdAt: serverTimestamp(),
    });
    claim.set(ownerRef(d, STRANGER), { code: 'WXY234' });
    await assertFails(claim.commit());

    // Landing on somebody's list.
    await assertFails(
      setDoc(
        listRef(d, VICTIM, STRANGER),
        friendEntry('Nobody', VICTIM_CODE),
      ),
    );

    // Publishing a scoreboard, and taking someone else's off.
    await assertFails(
      setDoc(progressRef(d, STRANGER), progressDoc(VICTIM_CODE)),
    );
    await assertFails(deleteDoc(progressRef(d, VICTIM)));

    // Writing into someone's block list, and taking their friendship apart.
    await assertFails(
      setDoc(blockRef(d, VICTIM, STRANGER), { since: serverTimestamp() }),
    );
    await assertFails(deleteDoc(listRef(d, VICTIM, STRANGER)));
  });

  test('16. a removed friend loses the scoreboard with the friendship', async () => {
    await seedClaimedCode(env, ATTACKER, ATTACKER_CODE, 'Attacker');
    await seedClaimedCode(env, VICTIM, VICTIM_CODE, 'Victim');
    await seedListEntry(env, VICTIM, ATTACKER, 'Attacker', ATTACKER_CODE);
    await seedListEntry(env, ATTACKER, VICTIM, 'Victim', VICTIM_CODE);
    await seedProgress(env, VICTIM, VICTIM_CODE);

    // While they are friends the scoreboard is readable…
    const attacker = db(fullAccount(env, ATTACKER));
    await assertSucceeds(getDoc(progressRef(attacker, VICTIM)));

    // …then the victim removes them, exactly as FriendsRepository.remove does.
    const victim = db(fullAccount(env, VICTIM));
    const removal = writeBatch(victim);
    removal.delete(listRef(victim, VICTIM, ATTACKER));
    removal.delete(listRef(victim, ATTACKER, VICTIM));
    removal.set(blockRef(victim, VICTIM, ATTACKER), {
      since: serverTimestamp(),
    });
    await assertSucceeds(removal.commit());

    // The read that worked a moment ago is refused now.
    await assertFails(getDoc(progressRef(attacker, VICTIM)));
  });

  test('17. a surviving mirror is not a re-entry ticket', async () => {
    await seedClaimedCode(env, ATTACKER, ATTACKER_CODE, 'Attacker');
    await seedClaimedCode(env, VICTIM, VICTIM_CODE, 'Victim');
    // My own side of an old friendship, kept deliberately: the victim deleted
    // their side (or removed me and I deleted their block's cause), and mine
    // still holds their code.
    await seedListEntry(env, ATTACKER, VICTIM, 'Victim', VICTIM_CODE);
    const d = db(fullAccount(env, ATTACKER));

    // `existsAfter` on the mirror alone would be satisfied by that untouched
    // entry, which would make one proof of holding the code good for ever.
    await assertFails(
      setDoc(
        listRef(d, VICTIM, ATTACKER),
        friendEntry('Attacker', ATTACKER_CODE),
      ),
    );
  });

  test('18. a list entry cannot be written without a since', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedClaimedCode(env, THEM, THEIR_CODE, 'Yusuf');
    const d = db(fullAccount(env, ME));

    // The list is ordered by `since`, so an entry without one would be
    // invisible on the screen while being entirely real to the rules.
    await assertFails(
      setDoc(listRef(d, ME, THEM), { name: 'Yusuf', code: THEIR_CODE }),
    );
  });

  test('19. a list entry name must be a string', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedClaimedCode(env, THEM, THEIR_CODE, 'Yusuf');
    const d = db(fullAccount(env, ME));

    await assertFails(
      setDoc(listRef(d, ME, THEM), friendEntry(42, THEIR_CODE)),
    );
  });

  test('20. an existing list entry can never be edited', async () => {
    await seedClaimedCode(env, THEM, THEIR_CODE, 'Yusuf');
    await seedListEntry(env, ME, THEM, 'Yusuf', THEIR_CODE);
    const d = db(fullAccount(env, ME));

    // Both shapes of edit: a whole-document set over it, and a field update.
    await assertFails(
      setDoc(listRef(d, ME, THEM), friendEntry('Yusuf', THEIR_CODE)),
    );
    await assertFails(updateDoc(listRef(d, ME, THEM), { name: 'Renamed' }));
  });

  test('21. nobody else’s list or block list can be read', async () => {
    await seedClaimedCode(env, THEM, THEIR_CODE, 'Yusuf');
    await seedListEntry(env, VICTIM, THEM, 'Yusuf', THEIR_CODE);
    await seedBlock(env, VICTIM, STRANGER);
    const d = db(fullAccount(env, ATTACKER));

    // Who someone's friends are, and whom they have cut off, is theirs.
    await assertFails(getDoc(listRef(d, VICTIM, THEM)));
    await assertFails(getDocs(collection(d, 'friends', VICTIM, 'list')));
    await assertFails(getDoc(blockRef(d, VICTIM, STRANGER)));
    await assertFails(getDocs(collection(d, 'friends', VICTIM, 'blocked')));
  });

  test('22. a block can only be written by the person doing the blocking', async () => {
    const d = db(fullAccount(env, ATTACKER));

    // Writing a block into someone else's collection would let anyone cut two
    // other people off from each other.
    await assertFails(
      setDoc(blockRef(d, VICTIM, STRANGER), { since: serverTimestamp() }),
    );
    // Including onto themselves, which would be a self-inflicted permanent ban
    // the victim never asked for.
    await assertFails(
      setDoc(blockRef(d, VICTIM, ATTACKER), { since: serverTimestamp() }),
    );
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// MUST BE ALLOWED — the honest client. A failure here is a broken feature.
// ═══════════════════════════════════════════════════════════════════════════
describe('the honest client', () => {
  test('a. claims its first code, code document and marker together', async () => {
    const d = db(fullAccount(env, ME));

    // `_claimCode` does this in a transaction, having first read the code
    // document to check it is free. rules-unit-testing cannot replay a client
    // transaction (its read step happens outside the rules' view), so the
    // write half is reproduced as a batch — which is the same thing as far as
    // the rules are concerned: both are one atomic request, and `getAfter` on
    // the marker is evaluated against exactly this set of writes.
    const batch = writeBatch(d);
    batch.set(codeRef(d, MY_CODE), {
      uid: ME,
      name: 'Aisha',
      createdAt: serverTimestamp(),
    });
    batch.set(ownerRef(d, ME), { code: MY_CODE });
    await assertSucceeds(batch.commit());
  });

  test('b. reads its own code document, and another person’s by id', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedClaimedCode(env, THEM, THEIR_CODE, 'Yusuf');
    const d = db(fullAccount(env, ME));

    await assertSucceeds(getDoc(codeRef(d, MY_CODE)));
    // Looking up the code someone typed is how adding a friend works at all.
    const theirs = await assertSucceeds(getDoc(codeRef(d, THEIR_CODE)));
    expect(theirs.data().uid).toBe(THEM);

    // And the marker, which is how a phone recovers a code whose write onto
    // the profile was lost rather than claiming a second one.
    await assertSucceeds(getDoc(ownerRef(d, ME)));
  });

  test('c. files the code onto its own user document with merge', async () => {
    await seedUser(env, ME, { displayName: 'Aisha' });
    const d = db(fullAccount(env, ME));

    await assertSucceeds(
      setDoc(userRef(d, ME), { friendCode: MY_CODE }, { merge: true }),
    );
  });

  test('d. adds a friend: one batch, block cleared, both sides written', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedClaimedCode(env, THEM, THEIR_CODE, 'Yusuf');
    const d = db(fullAccount(env, ME));

    // Exactly FriendsRepository.addByCode: the delete is of a block that in
    // the usual case is not there at all.
    const batch = writeBatch(d);
    batch.delete(blockRef(d, ME, THEM));
    batch.set(listRef(d, ME, THEM), friendEntry('Yusuf', THEIR_CODE));
    batch.set(listRef(d, THEM, ME), friendEntry('Aisha', MY_CODE));
    await assertSucceeds(batch.commit());
  });

  test('e. reads its own list, newest friendship first', async () => {
    await seedClaimedCode(env, THEM, THEIR_CODE, 'Yusuf');
    await seedClaimedCode(env, STRANGER, STRANGER_CODE, 'Bilal');
    await seedListEntry(env, ME, THEM, 'Yusuf', THEIR_CODE);
    await seedListEntry(env, ME, STRANGER, 'Bilal', STRANGER_CODE);
    const d = db(fullAccount(env, ME));

    const snap = await assertSucceeds(
      getDocs(
        query(collection(d, 'friends', ME, 'list'), orderBy('since', 'desc')),
      ),
    );
    expect(snap.size).toBe(2);
  });

  test('f. publishes its own progress, and republishes it', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));

    // A plain set, never a merge: the document is replaced wholesale so a
    // stray field from an older build cannot fail `hasOnly` for ever.
    await assertSucceeds(setDoc(progressRef(d, ME), progressDoc(MY_CODE)));
    await assertSucceeds(
      setDoc(
        progressRef(d, ME),
        progressDoc(MY_CODE, {
          streak: 4,
          todayCompleted: 5,
          lastCompletedDate: '2026-09-14',
        }),
      ),
    );
  });

  test('g. lets a friend read the scoreboard once they are on the list', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedProgress(env, ME, MY_CODE);
    await seedListEntry(env, ME, THEM, 'Yusuf', THEIR_CODE);
    const d = db(fullAccount(env, THEM));

    const snap = await assertSucceeds(getDoc(progressRef(d, ME)));
    expect(snap.data().streak).toBe(3);
  });

  test('h. removes a friend: both entries deleted and a block written at once', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedClaimedCode(env, THEM, THEIR_CODE, 'Yusuf');
    await seedListEntry(env, ME, THEM, 'Yusuf', THEIR_CODE);
    await seedListEntry(env, THEM, ME, 'Aisha', MY_CODE);
    const d = db(fullAccount(env, ME));

    const batch = writeBatch(d);
    batch.delete(listRef(d, ME, THEM));
    batch.delete(listRef(d, THEM, ME));
    batch.set(blockRef(d, ME, THEM), { since: serverTimestamp() });
    await assertSucceeds(batch.commit());
  });

  test('i. adds back someone it had blocked, lifting the block in the batch', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedClaimedCode(env, THEM, THEIR_CODE, 'Yusuf');
    await seedBlock(env, ME, THEM);
    const d = db(fullAccount(env, ME));

    const batch = writeBatch(d);
    batch.delete(blockRef(d, ME, THEM));
    batch.set(listRef(d, ME, THEM), friendEntry('Yusuf', THEIR_CODE));
    batch.set(listRef(d, THEM, ME), friendEntry('Aisha', MY_CODE));
    await assertSucceeds(batch.commit());
  });

  test('j. reads and deletes its own block', async () => {
    await seedBlock(env, ME, THEM);
    const d = db(fullAccount(env, ME));

    await assertSucceeds(getDoc(blockRef(d, ME, THEM)));
    await assertSucceeds(deleteDoc(blockRef(d, ME, THEM)));
  });

  test('k. publishes progress with no last completed day', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));

    // Nobody has finished a day yet: the publisher sends an explicit null…
    await assertSucceeds(
      setDoc(
        progressRef(d, ME),
        progressDoc(MY_CODE, { streak: 0, lastCompletedDate: null }),
      ),
    );

    // …and a document written without the key at all is equally fine.
    const absent = progressDoc(MY_CODE, { streak: 0 });
    delete absent.lastCompletedDate;
    await assertSucceeds(setDoc(progressRef(d, ME), absent));
  });

  test('l. lets a guest who has linked an email use Friends', async () => {
    // `sign_in_provider` goes on saying 'anonymous' for the rest of the
    // session after a link, so `identities` is what tells an upgraded guest
    // apart from a real one — otherwise linking an email would appear to work
    // and Friends would stay refused until the next sign-in.
    const d = db(upgradedGuest(env, ME));

    const batch = writeBatch(d);
    batch.set(codeRef(d, MY_CODE), {
      uid: ME,
      name: 'Aisha',
      createdAt: serverTimestamp(),
    });
    batch.set(ownerRef(d, ME), { code: MY_CODE });
    await assertSucceeds(batch.commit());

    await assertSucceeds(setDoc(progressRef(d, ME), progressDoc(MY_CODE)));
  });
});
