/**
 * Round two of Friends: circles — a shared forty days.
 *
 * circle_codes/{code} names a circle and is written once, by the creator,
 * in the same batch as circles/{circleId}. Nothing on a circle is readable
 * until you are a member; joining is an arrayUnion of your own uid with no
 * read first; leaving is the mirror; and each member's number lives on
 * circles/{circleId}/progress/{uid}, theirs to write and every member's to
 * read.
 */
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  arrayRemove,
  arrayUnion,
  collection,
  deleteDoc,
  getDoc,
  getDocs,
  query,
  setDoc,
  setLogLevel,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';

import {
  circleCodeRef,
  circleDoc,
  circleProgressColl,
  circleProgressDoc,
  circleProgressRef,
  circleRef,
  circlesColl,
  db,
  fullAccount,
  guestAccount,
  makeTestEnv,
  seedCircle,
  seedCircleProgress,
} from './support/env.js';

const CREATOR = 'uid_creator';
const JOINER = 'uid_joiner';
const OTHER = 'uid_other';
const STRANGER = 'uid_stranger';
const CIRCLE = 'circle_one';
const CODE = 'CDE345';

/// Exactly what `CircleActions.create` commits: the circle and the code
/// document that names it, in one batch.
function createCircle(d, circleId, creator, code, overrides = {}) {
  const batch = writeBatch(d);
  batch.set(circleRef(d, circleId), circleDoc(creator, code, overrides));
  batch.set(circleCodeRef(d, code), { circleId });
  return batch.commit();
}

/// Twenty members, none of them JOINER.
const TWENTY = Array.from({ length: 20 }, (_, i) => `uid_member_${i}`);

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
  test('1. a non-member cannot read a circle', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE);
    const d = db(fullAccount(env, STRANGER));

    await assertFails(getDoc(circleRef(d, CIRCLE)));
    // Nor list them — not unfiltered, and not filtered to somebody else.
    await assertFails(getDocs(circlesColl(d)));
    await assertFails(
      getDocs(query(circlesColl(d), where('members', 'array-contains', CREATOR))),
    );
    // A member cannot list the whole collection either.
    await assertFails(getDocs(circlesColl(db(fullAccount(env, CREATOR)))));
  });

  test('2. joining by adding two uids is refused', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE);
    const d = db(fullAccount(env, JOINER));

    // Myself and a friend in one go: the friend never asked.
    await assertFails(
      updateDoc(circleRef(d, CIRCLE), { members: arrayUnion(JOINER, OTHER) }),
    );
    await assertFails(
      updateDoc(circleRef(d, CIRCLE), { members: [CREATOR, JOINER, OTHER] }),
    );
    // Or somebody else on their own.
    await assertFails(
      updateDoc(circleRef(d, CIRCLE), { members: arrayUnion(OTHER) }),
    );
  });

  test('3. joining when the circle already has twenty members is refused', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE, { members: TWENTY });
    const d = db(fullAccount(env, JOINER));

    await assertFails(
      updateDoc(circleRef(d, CIRCLE), { members: arrayUnion(JOINER) }),
    );
  });

  test('4. a member cannot write another member’s progress', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE, { members: [CREATOR, JOINER] });
    const d = db(fullAccount(env, CREATOR));

    await assertFails(
      setDoc(circleProgressRef(d, CIRCLE, JOINER), circleProgressDoc()),
    );
    await seedCircleProgress(env, CIRCLE, JOINER);
    await assertFails(
      setDoc(circleProgressRef(d, CIRCLE, JOINER), circleProgressDoc({ kept: 0 })),
    );
    await assertFails(deleteDoc(circleProgressRef(d, CIRCLE, JOINER)));
  });

  test('5. a kept of forty-one is refused, and every other bad number', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE, { members: [CREATOR, JOINER] });
    const d = db(fullAccount(env, JOINER));
    const p = circleProgressRef(d, CIRCLE, JOINER);

    // Forty days has forty days in it.
    await assertFails(setDoc(p, circleProgressDoc({ kept: 41 })));
    await assertFails(setDoc(p, circleProgressDoc({ kept: -1 })));
    await assertFails(setDoc(p, circleProgressDoc({ kept: 7.5 })));
    await assertFails(setDoc(p, circleProgressDoc({ kept: '7' })));
    await assertFails(
      setDoc(
        p,
        circleProgressDoc({
          updatedAt: Timestamp.fromDate(new Date('2030-01-01T00:00:00Z')),
        }),
      ),
    );
    await assertFails(setDoc(p, circleProgressDoc({ note: 'missed Tuesday' })));
    await assertFails(setDoc(p, { updatedAt: circleProgressDoc().updatedAt }));
  });

  test('6. a circle_codes document can only be created by the creator, with the circle', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE);

    // Somebody else filing a second code for an existing circle.
    const stranger = db(fullAccount(env, STRANGER));
    await assertFails(setDoc(circleCodeRef(stranger, 'FGH456'), { circleId: CIRCLE }));

    // The creator filing a second code for it later: the circle already
    // exists, and a circle has one code.
    const creator = db(fullAccount(env, CREATOR));
    await assertFails(setDoc(circleCodeRef(creator, 'FGH456'), { circleId: CIRCLE }));

    // A batch shaped like an honest create, but with the circle in
    // somebody else's name.
    await assertFails(
      createCircle(stranger, 'circle_two', CREATOR, 'JKL567'),
    );

    // A code document that points at a circle the batch does not create.
    await assertFails(
      setDoc(circleCodeRef(stranger, 'JKL567'), { circleId: 'circle_nope' }),
    );

    // A code document with a second key, in an otherwise honest batch: it
    // is a pointer, and a pointer has one field.
    const extra = writeBatch(creator);
    extra.set(circleRef(creator, 'circle_two'), circleDoc(CREATOR, 'JKL567'));
    extra.set(circleCodeRef(creator, 'JKL567'), {
      circleId: 'circle_two',
      note: 'x',
    });
    await assertFails(extra.commit());
  });

  test('7. circle_codes cannot be listed, updated or deleted', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE);

    const stranger = db(fullAccount(env, STRANGER));
    await assertFails(getDocs(collection(stranger, 'circle_codes')));
    await assertFails(updateDoc(circleCodeRef(stranger, CODE), { circleId: 'x' }));
    await assertFails(deleteDoc(circleCodeRef(stranger, CODE)));

    // Not even the creator: a code never changes hands.
    const creator = db(fullAccount(env, CREATOR));
    await assertFails(updateDoc(circleCodeRef(creator, CODE), { circleId: 'x' }));
    await assertFails(deleteDoc(circleCodeRef(creator, CODE)));
    // And a signed-out client cannot resolve one.
    await assertFails(getDoc(circleCodeRef(db(env.unauthenticatedContext()), CODE)));
  });

  test('8. a non-member can neither read progress nor publish into the circle', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE);
    await seedCircleProgress(env, CIRCLE, CREATOR);
    const d = db(fullAccount(env, STRANGER));

    await assertFails(getDoc(circleProgressRef(d, CIRCLE, CREATOR)));
    await assertFails(getDocs(circleProgressColl(d, CIRCLE)));
    // Their own number, into a circle they are not in.
    await assertFails(
      setDoc(circleProgressRef(d, CIRCLE, STRANGER), circleProgressDoc()),
    );
  });

  test('9. nothing but the members list ever changes, and nobody deletes', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE, { members: [CREATOR, JOINER] });
    const d = db(fullAccount(env, CREATOR));
    const c = circleRef(d, CIRCLE);

    // What somebody joined is what it stays — even for the creator.
    await assertFails(updateDoc(c, { name: 'Renamed' }));
    await assertFails(updateDoc(c, { goal: 'five' }));
    await assertFails(updateDoc(c, { days: 41 }));
    await assertFails(updateDoc(c, { startsOn: '2026-10-01' }));
    await assertFails(updateDoc(c, { code: 'FGH456' }));
    await assertFails(updateDoc(c, { createdBy: JOINER }));
    await assertFails(
      updateDoc(c, { members: arrayRemove(CREATOR), name: 'Renamed' }),
    );
    await assertFails(setDoc(c, circleDoc(CREATOR, CODE, { name: 'Renamed' })));
    await assertFails(deleteDoc(c));
  });

  test('10. a member cannot remove, or add, anybody else', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE, { members: [CREATOR, JOINER] });

    const creator = db(fullAccount(env, CREATOR));
    await assertFails(
      updateDoc(circleRef(creator, CIRCLE), { members: arrayRemove(JOINER) }),
    );
    await assertFails(
      updateDoc(circleRef(creator, CIRCLE), { members: arrayUnion(OTHER) }),
    );
    await assertFails(
      updateDoc(circleRef(creator, CIRCLE), { members: [CREATOR] }),
    );

    const joiner = db(fullAccount(env, JOINER));
    await assertFails(
      updateDoc(circleRef(joiner, CIRCLE), { members: arrayRemove(CREATOR) }),
    );
    // Leaving and taking someone with you.
    await assertFails(
      updateDoc(circleRef(joiner, CIRCLE), { members: arrayRemove(CREATOR, JOINER) }),
    );
    // Nor themselves, twice: a member who is already on the list has
    // nothing to append, and a duplicate would count twice in the bar.
    await assertFails(
      updateDoc(circleRef(joiner, CIRCLE), { members: [CREATOR, JOINER, JOINER] }),
    );
  });

  test('11. a non-member cannot "leave", or touch the list at all', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE);
    const d = db(fullAccount(env, STRANGER));

    await assertFails(
      updateDoc(circleRef(d, CIRCLE), { members: arrayRemove(STRANGER) }),
    );
    await assertFails(
      updateDoc(circleRef(d, CIRCLE), { members: arrayRemove(CREATOR) }),
    );
    await assertFails(updateDoc(circleRef(d, CIRCLE), { members: [] }));
  });

  test('12. a circle cannot be created wrong', async () => {
    const d = db(fullAccount(env, CREATOR));

    const bad = [
      ['days 39', { days: 39 }],
      ['days as a string', { days: '40' }],
      ['two members from the start', { members: [CREATOR, JOINER] }],
      ['no members', { members: [] }],
      ['somebody else as the only member', { members: [JOINER] }],
      ['created in somebody else’s name', { createdBy: JOINER }],
      ['a goal that is not one of the three', { goal: 'dhuhr' }],
      ['a name of forty-one', { name: 'x'.repeat(41) }],
      ['an empty name', { name: '' }],
      ['a start day that is not a day id', { startsOn: 'soon' }],
      ['a client clock', {
        createdAt: Timestamp.fromDate(new Date('2030-01-01T00:00:00Z')),
      }],
      ['a ninth key', { description: 'for the brothers' }],
    ];
    for (const [why, overrides] of bad) {
      await assertFails(
        createCircle(d, CIRCLE, CREATOR, CODE, overrides),
        `${why} should be refused`,
      );
    }

    // A code the app could not have generated.
    for (const code of ['abc234', 'ABC-23', 'ABC2345', 'ABC23', 'ABC0O1']) {
      await assertFails(
        createCircle(d, CIRCLE, CREATOR, code),
        `code "${code}" should be refused`,
      );
    }

    // The circle without its code document, and with one that names a
    // different circle: a code that resolves to nothing is a circle nobody
    // can join.
    await assertFails(setDoc(circleRef(d, CIRCLE), circleDoc(CREATOR, CODE)));
    const wrong = writeBatch(d);
    wrong.set(circleRef(d, CIRCLE), circleDoc(CREATOR, CODE));
    wrong.set(circleCodeRef(d, CODE), { circleId: 'circle_other' });
    await assertFails(wrong.commit());
    // And a code document whose id is not the code on the circle.
    const mismatched = writeBatch(d);
    mismatched.set(circleRef(d, CIRCLE), circleDoc(CREATOR, CODE));
    mismatched.set(circleCodeRef(d, 'FGH456'), { circleId: CIRCLE });
    await assertFails(mismatched.commit());
  });

  test('13. a guest can neither create nor join', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE);
    const d = db(guestAccount(env, JOINER));

    await assertFails(createCircle(d, 'circle_two', JOINER, 'JKL567'));
    await assertFails(
      updateDoc(circleRef(d, CIRCLE), { members: arrayUnion(JOINER) }),
    );
    await assertFails(getDoc(circleCodeRef(d, CODE)));

    // Nor publish a number — not even into a circle that somehow lists
    // them, since a guest could only have got there around the rules.
    await seedCircle(env, 'circle_two', CREATOR, 'JKL567', {
      members: [CREATOR, JOINER],
    });
    await assertFails(
      setDoc(circleProgressRef(d, 'circle_two', JOINER), circleProgressDoc()),
    );
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// MUST BE ALLOWED
// ═══════════════════════════════════════════════════════════════════════════
describe('the honest client', () => {
  test('a. creates a circle: the circle and its code in one batch', async () => {
    const d = db(fullAccount(env, CREATOR));

    await assertSucceeds(createCircle(d, CIRCLE, CREATOR, CODE));
    await assertSucceeds(
      createCircle(d, 'circle_two', CREATOR, 'JKL567', {
        goal: 'tahajjud',
        name: 'x'.repeat(40),
      }),
    );
    const snap = await assertSucceeds(getDoc(circleRef(d, CIRCLE)));
    expect(snap.data().members).toEqual([CREATOR]);
  });

  test('b. resolves a code it was given', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE);
    const d = db(fullAccount(env, JOINER));

    const snap = await assertSucceeds(getDoc(circleCodeRef(d, CODE)));
    expect(snap.data().circleId).toBe(CIRCLE);
  });

  test('c. joins with an arrayUnion and no read first, then can read', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE);
    const d = db(fullAccount(env, JOINER));

    // Before: nothing on the circle is theirs to see.
    await assertFails(getDoc(circleRef(d, CIRCLE)));

    // Exactly `CircleActions.join`: the code resolved, the uid appended.
    await assertSucceeds(
      updateDoc(circleRef(d, CIRCLE), { members: arrayUnion(JOINER) }),
    );

    // After: the circle, and the list of "mine".
    const snap = await assertSucceeds(getDoc(circleRef(d, CIRCLE)));
    expect(snap.data().members).toEqual([CREATOR, JOINER]);
    const mine = await assertSucceeds(
      getDocs(query(circlesColl(d), where('members', 'array-contains', JOINER))),
    );
    expect(mine.size).toBe(1);
  });

  test('d. joining a circle it is already in changes nothing, and is not refused', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE, { members: [CREATOR, JOINER] });
    const d = db(fullAccount(env, JOINER));

    // Typing your own circle's code into the add field.
    await assertSucceeds(
      updateDoc(circleRef(d, CIRCLE), { members: arrayUnion(JOINER) }),
    );
    const snap = await assertSucceeds(getDoc(circleRef(d, CIRCLE)));
    expect(snap.data().members).toEqual([CREATOR, JOINER]);
  });

  test('e. the twentieth member fits', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE, { members: TWENTY.slice(0, 19) });
    const d = db(fullAccount(env, JOINER));

    await assertSucceeds(
      updateDoc(circleRef(d, CIRCLE), { members: arrayUnion(JOINER) }),
    );
  });

  test('f. publishes its own number and reads everyone’s', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE, { members: [CREATOR, JOINER] });
    await seedCircleProgress(env, CIRCLE, CREATOR, { kept: 12 });
    const d = db(fullAccount(env, JOINER));
    const p = circleProgressRef(d, CIRCLE, JOINER);

    await assertSucceeds(setDoc(p, circleProgressDoc({ kept: 0 })));
    await assertSucceeds(setDoc(p, circleProgressDoc({ kept: 7 })));
    await assertSucceeds(setDoc(p, circleProgressDoc({ kept: 40 })));

    const all = await assertSucceeds(getDocs(circleProgressColl(d, CIRCLE)));
    expect(all.size).toBe(2);
    const theirs = await assertSucceeds(getDoc(circleProgressRef(d, CIRCLE, CREATOR)));
    expect(theirs.data().kept).toBe(12);
  });

  test('g. leaves with an arrayRemove, taking its number with it', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE, { members: [CREATOR, JOINER] });
    await seedCircleProgress(env, CIRCLE, JOINER);
    const d = db(fullAccount(env, JOINER));

    const batch = writeBatch(d);
    batch.update(circleRef(d, CIRCLE), { members: arrayRemove(JOINER) });
    batch.delete(circleProgressRef(d, CIRCLE, JOINER));
    await assertSucceeds(batch.commit());

    // Gone means gone: the circle and its numbers are closed again.
    await assertFails(getDoc(circleRef(d, CIRCLE)));
    await assertFails(getDocs(circleProgressColl(d, CIRCLE)));
    const creator = db(fullAccount(env, CREATOR));
    const snap = await assertSucceeds(getDoc(circleRef(creator, CIRCLE)));
    expect(snap.data().members).toEqual([CREATOR]);
  });

  test('h. the last member may leave, which is how a circle ends', async () => {
    await seedCircle(env, CIRCLE, CREATOR, CODE);
    const d = db(fullAccount(env, CREATOR));

    await assertSucceeds(
      updateDoc(circleRef(d, CIRCLE), { members: arrayRemove(CREATOR) }),
    );
  });
});
