/**
 * Round two of Friends: inbox/{toUid}/items/{itemId}, things a friend sent.
 *
 * Three kinds and no fourth, each with exactly its own keys and no text
 * field on any of them, because the rule is "no messages between people".
 * Only someone on the recipient's list may send; only the recipient reads
 * and deletes; nobody edits.
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
  circleItem,
  db,
  eidItem,
  fullAccount,
  guestAccount,
  inboxColl,
  inboxItemRef,
  makeTestEnv,
  seedCircle,
  seedFriends,
  seedInboxItem,
  seedListEntry,
  verseItem,
} from './support/env.js';

const ME = 'uid_me'; // the sender
const THEM = 'uid_them'; // the recipient
const OTHER = 'uid_other';
const STRANGER = 'uid_stranger';
const CIRCLE = 'circle_one';
const CIRCLE_CODE = 'CDE345';

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
  test('1. an item with free text on it is refused', async () => {
    await seedFriends(env, ME, THEM);
    await seedCircle(env, CIRCLE, ME, CIRCLE_CODE);
    const d = db(fullAccount(env, ME));
    const item = inboxItemRef(d, THEM, 'item1');

    // A string field of any name, on any kind, is a message.
    await assertFails(setDoc(item, verseItem(ME, { text: 'call me' })));
    await assertFails(setDoc(item, eidItem(ME, { message: 'Eid Mubarak!' })));
    await assertFails(
      setDoc(item, circleItem(ME, CIRCLE, CIRCLE_CODE, { note: 'join us' })),
    );
    // And the one string every kind carries is bounded like every name.
    await assertFails(setDoc(item, eidItem(ME, { fromName: 'x'.repeat(41) })));
    await assertFails(setDoc(item, eidItem(ME, { fromName: '' })));
    await assertFails(setDoc(item, eidItem(ME, { fromName: 7 })));
  });

  test('2. an item of an unknown type is refused', async () => {
    await seedFriends(env, ME, THEM);
    const d = db(fullAccount(env, ME));
    const item = inboxItemRef(d, THEM, 'item1');

    await assertFails(setDoc(item, { ...eidItem(ME), type: 'note' }));
    await assertFails(setDoc(item, { ...eidItem(ME), type: 'Eid' }));
    await assertFails(setDoc(item, { ...verseItem(ME), type: 'dua' }));
    const untyped = eidItem(ME);
    delete untyped.type;
    await assertFails(setDoc(item, untyped));
  });

  test('3. a verse without a card, or with the wrong card, is refused', async () => {
    await seedFriends(env, ME, THEM);
    const d = db(fullAccount(env, ME));
    const item = inboxItemRef(d, THEM, 'item1');

    const noCard = verseItem(ME);
    delete noCard.comfortId;
    await assertFails(setDoc(item, noCard));
    await assertFails(setDoc(item, verseItem(ME, { comfortId: '' })));
    await assertFails(setDoc(item, verseItem(ME, { comfortId: 'x'.repeat(81) })));
    await assertFails(setDoc(item, verseItem(ME, { comfortId: 7 })));
    // Each kind carries exactly its own keys: a greeting with a card on it
    // is neither.
    await assertFails(setDoc(item, eidItem(ME, { comfortId: 'anxious_1' })));
    await assertFails(
      setDoc(item, verseItem(ME, { circleId: CIRCLE, circleCode: CIRCLE_CODE })),
    );
  });

  test('4. an invitation that is not to the sender’s own circle is refused', async () => {
    await seedFriends(env, ME, THEM);
    const d = db(fullAccount(env, ME));
    const item = inboxItemRef(d, THEM, 'item1');

    // A circle the sender is not in — they only know its id and code.
    await seedCircle(env, CIRCLE, STRANGER, CIRCLE_CODE);
    await assertFails(setDoc(item, circleItem(ME, CIRCLE, CIRCLE_CODE)));

    // A circle that does not exist.
    await assertFails(setDoc(item, circleItem(ME, 'circle_nope', 'FGH456')));

    // The sender's own circle, with the wrong code — a Join that fails.
    await seedCircle(env, 'circle_two', ME, 'JKL567');
    await assertFails(setDoc(item, circleItem(ME, 'circle_two', 'MNP678')));
    await assertFails(setDoc(item, circleItem(ME, 'circle_two', 'jkl567')));
    await assertFails(setDoc(item, circleItem(ME, 'circle_two', 'JKL56')));
    const noCode = circleItem(ME, 'circle_two', 'JKL567');
    delete noCode.circleCode;
    await assertFails(setDoc(item, noCode));
    const noId = circleItem(ME, 'circle_two', 'JKL567');
    delete noId.circleId;
    await assertFails(setDoc(item, noId));
    await assertFails(setDoc(item, circleItem(ME, 'x'.repeat(41), 'JKL567')));
  });

  test('5. a non-friend cannot send anything', async () => {
    const d = db(fullAccount(env, STRANGER));
    const item = inboxItemRef(d, THEM, 'item1');

    await assertFails(setDoc(item, verseItem(STRANGER)));
    await assertFails(setDoc(item, eidItem(STRANGER)));

    // Being on the sender's own list is not being on the recipient's.
    await seedListEntry(env, STRANGER, THEM, 'Them', 'XYZ789');
    await assertFails(setDoc(item, eidItem(STRANGER)));
  });

  test('6. an item cannot be sent in somebody else’s name', async () => {
    await seedFriends(env, ME, THEM);
    await seedFriends(env, OTHER, THEM);
    const d = db(fullAccount(env, ME));

    await assertFails(
      setDoc(inboxItemRef(d, THEM, 'item1'), verseItem(OTHER)),
    );
  });

  test('7. an item cannot carry a client clock, or no clock', async () => {
    await seedFriends(env, ME, THEM);
    const d = db(fullAccount(env, ME));
    const item = inboxItemRef(d, THEM, 'item1');

    await assertFails(
      setDoc(
        item,
        verseItem(ME, {
          at: Timestamp.fromDate(new Date('2030-01-01T00:00:00Z')),
        }),
      ),
    );
    const noClock = verseItem(ME);
    delete noClock.at;
    await assertFails(setDoc(item, noClock));
  });

  test('8. nobody but the recipient reads or deletes, and nobody edits', async () => {
    await seedFriends(env, ME, THEM);
    await seedInboxItem(env, THEM, 'item1', verseItem(ME));

    // The sender cannot see whether it was opened, or take it back.
    const me = db(fullAccount(env, ME));
    await assertFails(getDoc(inboxItemRef(me, THEM, 'item1')));
    await assertFails(getDocs(inboxColl(me, THEM)));
    await assertFails(deleteDoc(inboxItemRef(me, THEM, 'item1')));
    await assertFails(
      updateDoc(inboxItemRef(me, THEM, 'item1'), { comfortId: 'sad_2' }),
    );

    const stranger = db(fullAccount(env, STRANGER));
    await assertFails(getDoc(inboxItemRef(stranger, THEM, 'item1')));
    await assertFails(getDocs(inboxColl(stranger, THEM)));

    // Not even the recipient edits: an item is what was sent, or gone.
    const them = db(fullAccount(env, THEM));
    await assertFails(
      updateDoc(inboxItemRef(them, THEM, 'item1'), { comfortId: 'sad_2' }),
    );
  });

  test('9. a guest cannot send, even from the list', async () => {
    await seedFriends(env, ME, THEM);
    const d = db(guestAccount(env, ME));

    await assertFails(setDoc(inboxItemRef(d, THEM, 'item1'), eidItem(ME)));
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// MUST BE ALLOWED
// ═══════════════════════════════════════════════════════════════════════════
describe('the honest client', () => {
  test('a. sends a verse', async () => {
    await seedFriends(env, ME, THEM);
    const d = db(fullAccount(env, ME));

    await assertSucceeds(setDoc(inboxItemRef(d, THEM, 'item1'), verseItem(ME)));
    await assertSucceeds(
      setDoc(
        inboxItemRef(d, THEM, 'item2'),
        verseItem(ME, { comfortId: 'x'.repeat(80) }),
      ),
    );
  });

  test('b. sends Eid greetings to every friend', async () => {
    await seedFriends(env, ME, THEM);
    await seedFriends(env, ME, OTHER);
    const d = db(fullAccount(env, ME));

    await assertSucceeds(setDoc(inboxItemRef(d, THEM, 'eid1'), eidItem(ME)));
    await assertSucceeds(setDoc(inboxItemRef(d, OTHER, 'eid1'), eidItem(ME)));
  });

  test('c. invites a friend to a circle it is in', async () => {
    await seedFriends(env, ME, THEM);
    const d = db(fullAccount(env, ME));

    // One it created…
    await seedCircle(env, CIRCLE, ME, CIRCLE_CODE);
    await assertSucceeds(
      setDoc(inboxItemRef(d, THEM, 'inv1'), circleItem(ME, CIRCLE, CIRCLE_CODE)),
    );
    // …and one it only joined.
    await seedCircle(env, 'circle_two', STRANGER, 'JKL567', {
      members: [STRANGER, ME],
    });
    await assertSucceeds(
      setDoc(inboxItemRef(d, THEM, 'inv2'), circleItem(ME, 'circle_two', 'JKL567')),
    );
  });

  test('d. the recipient reads the strip and dismisses an item', async () => {
    await seedFriends(env, ME, THEM);
    await seedInboxItem(env, THEM, 'item1', verseItem(ME));
    await seedInboxItem(env, THEM, 'item2', eidItem(ME));
    const d = db(fullAccount(env, THEM));

    const snap = await assertSucceeds(getDocs(inboxColl(d, THEM)));
    expect(snap.size).toBe(2);
    const one = await assertSucceeds(getDoc(inboxItemRef(d, THEM, 'item1')));
    expect(one.data().comfortId).toBe('anxious_1');
    await assertSucceeds(deleteDoc(inboxItemRef(d, THEM, 'item1')));
  });
});
