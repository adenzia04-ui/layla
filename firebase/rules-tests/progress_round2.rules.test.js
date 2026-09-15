/**
 * Round two of Friends: the three keys added to progress/{uid}.
 *
 * `quiet`, `milestone` and `ramadan` are each a new thing a friend can see,
 * and each is held to a shape here — quiet to more than a shape: a quiet
 * scoreboard has to BE quiet, all zeros, on the server. And the one thing
 * that must not change with a longer key list is what the list still keeps
 * out: nothing about the pause.
 *
 * Runs against the real rules file through `npm run emu`, like the rest.
 */
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { getDoc, setDoc, setLogLevel } from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, expect, test } from 'vitest';

import {
  db,
  fullAccount,
  makeTestEnv,
  milestone,
  progressDoc,
  progressRef,
  ramadanShare,
  seedClaimedCode,
  seedListEntry,
  seedProgress,
} from './support/env.js';

const ME = 'uid_me';
const THEM = 'uid_them';
const STRANGER = 'uid_stranger';
const MY_CODE = 'ABC234';
const THEIR_CODE = 'XYZ789';

const KEYS = [
  'streak100',
  'streak365',
  'prayers1000',
  'prayers5000',
  'tahajjud1',
  'tahajjud100',
];

/// What "Go quiet" publishes: every counter zero, no last day, nothing else.
function quietDoc(code, overrides = {}) {
  return progressDoc(code, {
    quiet: true,
    streak: 0,
    longestStreak: 0,
    totalPrayers: 0,
    totalTahajjud: 0,
    todayCompleted: 0,
    lastCompletedDate: null,
    ...overrides,
  });
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
});

// ═══════════════════════════════════════════════════════════════════════════
// MUST BE DENIED
// ═══════════════════════════════════════════════════════════════════════════
describe('quiet: what must be refused', () => {
  test('1. a quiet that is not a bool is refused', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));
    const p = progressRef(d, ME);

    await assertFails(setDoc(p, quietDoc(MY_CODE, { quiet: 'yes' })));
    await assertFails(setDoc(p, quietDoc(MY_CODE, { quiet: 1 })));
  });

  test('2. quiet with the numbers still on it is refused', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));
    const p = progressRef(d, ME);

    // A scoreboard that says quiet and publishes anyway is the case the
    // server exists for: the friend's phone would hide it, a raw SDK would
    // not — one counter at a time, so that each clause is the one refusing.
    await assertFails(
      setDoc(p, quietDoc(MY_CODE, { streak: 3, longestStreak: 3 })),
    );
    await assertFails(setDoc(p, quietDoc(MY_CODE, { longestStreak: 12 })));
    await assertFails(setDoc(p, quietDoc(MY_CODE, { totalPrayers: 900 })));
    await assertFails(setDoc(p, quietDoc(MY_CODE, { totalTahajjud: 1 })));
    await assertFails(setDoc(p, quietDoc(MY_CODE, { todayCompleted: 2 })));
    await assertFails(
      setDoc(p, quietDoc(MY_CODE, { lastCompletedDate: '2026-09-13' })),
    );
    // And nothing from which a week could be read back, either.
    await assertFails(
      setDoc(p, quietDoc(MY_CODE, { milestone: milestone() })),
    );
    await assertFails(setDoc(p, quietDoc(MY_CODE, { ramadan: ramadanShare() })));
  });
});

describe('milestone: what must be refused', () => {
  test('3. an unknown milestone key is refused', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));
    const p = progressRef(d, ME);

    // A seventh word reaches a switch with six cases.
    await assertFails(
      setDoc(p, progressDoc(MY_CODE, { milestone: milestone('streak50') })),
    );
    await assertFails(
      setDoc(p, progressDoc(MY_CODE, { milestone: milestone('STREAK100') })),
    );
    await assertFails(
      setDoc(p, progressDoc(MY_CODE, { milestone: milestone('') })),
    );
    await assertFails(
      setDoc(
        p,
        progressDoc(MY_CODE, { milestone: { ...milestone(), key: 7 } }),
      ),
    );
  });

  test('4. a milestone that is not exactly { key, at } is refused', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));
    const p = progressRef(d, ME);

    // Not a map at all.
    await assertFails(
      setDoc(p, progressDoc(MY_CODE, { milestone: 'streak100' })),
    );
    // Half a milestone, either half.
    await assertFails(
      setDoc(p, progressDoc(MY_CODE, { milestone: { key: 'streak100' } })),
    );
    await assertFails(
      setDoc(p, progressDoc(MY_CODE, { milestone: { at: milestone().at } })),
    );
    // A third key — a map on a friend-readable document is a place to
    // smuggle, and the map is closed for the same reason the document is.
    await assertFails(
      setDoc(
        p,
        progressDoc(MY_CODE, {
          milestone: { ...milestone(), note: 'alhamdulillah' },
        }),
      ),
    );
    // A day that is not a timestamp.
    await assertFails(
      setDoc(
        p,
        progressDoc(MY_CODE, { milestone: { key: 'streak100', at: '2026-09-10' } }),
      ),
    );
    await assertFails(
      setDoc(
        p,
        progressDoc(MY_CODE, { milestone: { key: 'streak100', at: 1757480400 } }),
      ),
    );
  });
});

describe('ramadan: what must be refused', () => {
  test('5. fasts past thirty, below zero, or not an int are refused', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));
    const p = progressRef(d, ME);

    await assertFails(
      setDoc(p, progressDoc(MY_CODE, { ramadan: ramadanShare({ fasts: 31 }) })),
    );
    await assertFails(
      setDoc(p, progressDoc(MY_CODE, { ramadan: ramadanShare({ fasts: -1 }) })),
    );
    await assertFails(
      setDoc(p, progressDoc(MY_CODE, { ramadan: ramadanShare({ fasts: 12.5 }) })),
    );
    await assertFails(
      setDoc(p, progressDoc(MY_CODE, { ramadan: ramadanShare({ fasts: '12' }) })),
    );
  });

  test('6. a Ramadan line that is not exactly the four keys is refused', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));
    const p = progressRef(d, ME);

    await assertFails(setDoc(p, progressDoc(MY_CODE, { ramadan: 12 })));

    const missing = ramadanShare();
    delete missing.taraweeh;
    await assertFails(setDoc(p, progressDoc(MY_CODE, { ramadan: missing })));

    await assertFails(
      setDoc(
        p,
        progressDoc(MY_CODE, { ramadan: ramadanShare({ mood: 'grateful' }) }),
      ),
    );
    await assertFails(
      setDoc(
        p,
        progressDoc(MY_CODE, { ramadan: ramadanShare({ fastingToday: 'yes' }) }),
      ),
    );
    await assertFails(
      setDoc(
        p,
        progressDoc(MY_CODE, { ramadan: ramadanShare({ taraweeh: 1 }) }),
      ),
    );
    await assertFails(
      setDoc(
        p,
        progressDoc(MY_CODE, { ramadan: ramadanShare({ date: '20/02/2027' }) }),
      ),
    );
  });
});

describe('the pause still cannot reach the scoreboard', () => {
  test('7. cycle, gender and excused are refused beside the new keys', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));
    const p = progressRef(d, ME);

    // The key list grew by three. It did not grow by these.
    await assertFails(
      setDoc(
        p,
        progressDoc(MY_CODE, {
          milestone: milestone(),
          cycle: { startedOn: '2026-09-12' },
        }),
      ),
    );
    await assertFails(setDoc(p, quietDoc(MY_CODE, { gender: 'sister' })));
    await assertFails(
      setDoc(
        p,
        progressDoc(MY_CODE, { ramadan: ramadanShare(), excused: true }),
      ),
    );
    await assertFails(setDoc(p, quietDoc(MY_CODE, { cycle: null })));
  });

  test('8. and cannot hide inside them', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));
    const p = progressRef(d, ME);

    // Both new maps are closed: a key the friend's phone would never look
    // at is still a key the friend's phone downloads.
    await assertFails(
      setDoc(
        p,
        progressDoc(MY_CODE, {
          milestone: { ...milestone(), cycle: { startedOn: '2026-09-12' } },
        }),
      ),
    );
    await assertFails(
      setDoc(
        p,
        progressDoc(MY_CODE, { ramadan: ramadanShare({ excused: true }) }),
      ),
    );
    await assertFails(
      setDoc(
        p,
        progressDoc(MY_CODE, { ramadan: ramadanShare({ gender: 'sister' }) }),
      ),
    );
  });

  test('9. a stranger still cannot read a scoreboard that carries them', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedProgress(env, ME, MY_CODE, {
      quiet: false,
      milestone: milestone(),
      ramadan: ramadanShare(),
    });
    const d = db(fullAccount(env, STRANGER));

    await assertFails(getDoc(progressRef(d, ME)));
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// MUST BE ALLOWED
// ═══════════════════════════════════════════════════════════════════════════
describe('the honest client', () => {
  test('a. the publish from before round two still passes, untouched', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));

    // The ten keys of the first round and none of the new ones: every phone
    // running the previous build publishes exactly this, and must go on
    // being able to.
    await assertSucceeds(setDoc(progressRef(d, ME), progressDoc(MY_CODE)));
    await assertSucceeds(
      setDoc(
        progressRef(d, ME),
        progressDoc(MY_CODE, { streak: 4, todayCompleted: 5 }),
      ),
    );
  });

  test('b. goes quiet: zeros, no last day, nothing else', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));
    const p = progressRef(d, ME);

    await assertSucceeds(setDoc(p, quietDoc(MY_CODE)));
    // The publisher may send the two maps as explicit nulls, the way it
    // sends the picture, so that its change detection sees a stable shape.
    await assertSucceeds(
      setDoc(p, quietDoc(MY_CODE, { milestone: null, ramadan: null })),
    );
    // Off again: the numbers come back.
    await assertSucceeds(setDoc(p, progressDoc(MY_CODE, { quiet: false })));
    await assertSucceeds(setDoc(p, progressDoc(MY_CODE, { quiet: null })));
  });

  test('c. publishes each of the six milestones', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));
    const p = progressRef(d, ME);

    for (const key of KEYS) {
      await assertSucceeds(
        setDoc(p, progressDoc(MY_CODE, { milestone: milestone(key) })),
        `milestone "${key}" should be accepted`,
      );
    }
    await assertSucceeds(setDoc(p, progressDoc(MY_CODE, { milestone: null })));
  });

  test('d. publishes the Ramadan line, at both ends of the month', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));
    const p = progressRef(d, ME);

    await assertSucceeds(
      setDoc(p, progressDoc(MY_CODE, { ramadan: ramadanShare() })),
    );
    await assertSucceeds(
      setDoc(
        p,
        progressDoc(MY_CODE, {
          ramadan: ramadanShare({ fasts: 0, fastingToday: false }),
        }),
      ),
    );
    await assertSucceeds(
      setDoc(
        p,
        progressDoc(MY_CODE, {
          ramadan: ramadanShare({ fasts: 30, taraweeh: true }),
        }),
      ),
    );
    await assertSucceeds(setDoc(p, progressDoc(MY_CODE, { ramadan: null })));
  });

  test('e. publishes all three at once', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));

    await assertSucceeds(
      setDoc(
        progressRef(d, ME),
        progressDoc(MY_CODE, {
          quiet: false,
          milestone: milestone('prayers1000'),
          ramadan: ramadanShare(),
        }),
      ),
    );
  });

  test('f. a friend reads the new keys off the scoreboard', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedProgress(env, ME, MY_CODE, {
      quiet: false,
      milestone: milestone('tahajjud1'),
      ramadan: ramadanShare(),
    });
    await seedListEntry(env, ME, THEM, 'Yusuf', THEIR_CODE);
    const d = db(fullAccount(env, THEM));

    const snap = await assertSucceeds(getDoc(progressRef(d, ME)));
    expect(snap.data().milestone.key).toBe('tahajjud1');
    expect(snap.data().ramadan.fasts).toBe(12);
    expect(snap.data().quiet).toBe(false);
  });

  test('g. a friend sees a quiet scoreboard as zeros and nothing more', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedProgress(env, ME, MY_CODE, {
      quiet: true,
      streak: 0,
      longestStreak: 0,
      totalPrayers: 0,
      totalTahajjud: 0,
      todayCompleted: 0,
      lastCompletedDate: null,
    });
    await seedListEntry(env, ME, THEM, 'Yusuf', THEIR_CODE);
    const d = db(fullAccount(env, THEM));

    const snap = await assertSucceeds(getDoc(progressRef(d, ME)));
    expect(snap.data().quiet).toBe(true);
    expect(snap.data().streak).toBe(0);
    expect(snap.data().totalPrayers).toBe(0);
    expect(snap.data().milestone).toBeUndefined();
    expect(snap.data().ramadan).toBeUndefined();
  });
});
