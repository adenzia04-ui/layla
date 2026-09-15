import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  serverTimestamp,
  setDoc,
  Timestamp,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));

/// The rules under test are the ones that ship — firebase/firestore.rules,
/// read off disk rather than copied, so the suite can never drift from the
/// file that is deployed. Resolved from this module rather than from the
/// process cwd so `vitest run` works from anywhere.
export const RULES_PATH = join(here, '..', '..', 'firestore.rules');

/// Firebase is on the Spark plan: no Cloud Functions are deployed, so these
/// rules are the only server-side enforcement the Friends feature has.
export function rulesSource() {
  return readFileSync(RULES_PATH, 'utf8');
}

export function makeTestEnv() {
  return initializeTestEnvironment({
    projectId: 'noor-rules-test',
    firestore: {
      rules: rulesSource(),
      host: '127.0.0.1',
      port: 8080,
    },
  });
}

/// A real account: signed in with a password, so `sign_in_provider` is not
/// 'anonymous' and `isFullAccount()` passes on its first branch.
export function fullAccount(env, uid) {
  return env.authenticatedContext(uid, {
    firebase: {
      sign_in_provider: 'password',
      identities: { email: [`${uid}@example.com`] },
    },
  });
}

/// A guest. A real anonymous token carries an empty `identities` map, which is
/// what makes `isFullAccount()`'s second branch refuse them as squarely as the
/// first one does.
export function guestAccount(env, uid) {
  return env.authenticatedContext(uid, {
    firebase: { sign_in_provider: 'anonymous', identities: {} },
  });
}

/// A guest session that has since linked an email — `sign_in_provider` still
/// says 'anonymous' for the life of the session, and `identities` is what
/// tells them apart from a guest who has linked nothing.
export function upgradedGuest(env, uid) {
  return env.authenticatedContext(uid, {
    firebase: {
      sign_in_provider: 'anonymous',
      identities: { email: [`${uid}@example.com`] },
    },
  });
}

export const db = (context) => context.firestore();

// ── Paths, mirroring FriendsRepository ────────────────────────────────────
export const codeRef = (d, code) => doc(d, 'friend_codes', code);
export const ownerRef = (d, uid) => doc(d, 'friend_code_owners', uid);
export const progressRef = (d, uid) => doc(d, 'progress', uid);
export const listRef = (d, uid, friendUid) =>
  doc(d, 'friends', uid, 'list', friendUid);
export const blockRef = (d, uid, otherUid) =>
  doc(d, 'friends', uid, 'blocked', otherUid);
export const userRef = (d, uid) => doc(d, 'users', uid);

/// users/{uid}/prayer_days/{dateId} — where an excused day is recorded, and
/// the only place in the database other than the profile itself that knows a
/// pause was on. Under the same owner-only rule as the profile.
export const prayerDayRef = (d, uid, dateId) =>
  doc(d, 'users', uid, 'prayer_days', dateId);

/// The whole subcollection, for proving nobody but the owner may list it.
export const prayerDaysRef = (d, uid) =>
  collection(d, 'users', uid, 'prayer_days');

// ── Document shapes ───────────────────────────────────────────────────────

/// What `Friend.toMap()` writes: a name, the other person's code, and the
/// server's clock.
export function friendEntry(name, code, overrides = {}) {
  return { name, code, since: serverTimestamp(), ...overrides };
}

/// What `FriendProgress.toMap()` writes, plus the `updatedAt` the repository
/// stamps on. All ten keys, in the shape the rules insist on.
export function progressDoc(code, overrides = {}) {
  return {
    name: 'Aisha',
    code,
    streak: 3,
    longestStreak: 12,
    totalPrayers: 900,
    totalTahajjud: 40,
    todayCompleted: 2,
    todayDate: '2026-09-14',
    lastCompletedDate: '2026-09-13',
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

// ── Seeding (rules off) ───────────────────────────────────────────────────

/// A claimed code: the code document and the write-once marker beside it,
/// exactly what `_claimCode` leaves behind.
export function seedClaimedCode(env, uid, code, name = 'Seeded') {
  return env.withSecurityRulesDisabled(async (ctx) => {
    const d = db(ctx);
    await setDoc(codeRef(d, code), {
      uid,
      name,
      createdAt: serverTimestamp(),
    });
    await setDoc(ownerRef(d, uid), { code });
  });
}

/// One side of a friendship: `friends/{uid}/list/{friendUid}`.
export function seedListEntry(env, uid, friendUid, name, code) {
  return env.withSecurityRulesDisabled((ctx) =>
    setDoc(listRef(db(ctx), uid, friendUid), {
      name,
      code,
      since: serverTimestamp(),
    }),
  );
}

/// `friends/{uid}/blocked/{otherUid}` — uid has removed otherUid.
export function seedBlock(env, uid, otherUid) {
  return env.withSecurityRulesDisabled((ctx) =>
    setDoc(blockRef(db(ctx), uid, otherUid), { since: serverTimestamp() }),
  );
}

export function seedProgress(env, uid, code, overrides = {}) {
  return env.withSecurityRulesDisabled((ctx) =>
    setDoc(progressRef(db(ctx), uid), progressDoc(code, overrides)),
  );
}

export function seedUser(env, uid, data) {
  return env.withSecurityRulesDisabled((ctx) =>
    setDoc(userRef(db(ctx), uid), data),
  );
}

/// A day as the app leaves it. The default is an ordinary day with nothing
/// prayed yet; pass `{ excused: true, ... }` for a day the pause covered.
export function seedPrayerDay(env, uid, dateId, data = { excused: true }) {
  return env.withSecurityRulesDisabled((ctx) =>
    setDoc(prayerDayRef(db(ctx), uid, dateId), data),
  );
}

// ── Round two: paths ──────────────────────────────────────────────────────

/// friends/{uid}/meta/{friendUid} — the owner's own "prayers together"
/// baseline for one friend. Owner-only, like the list beside it.
export const metaRef = (d, uid, friendUid) =>
  doc(d, 'friends', uid, 'meta', friendUid);
export const metaColl = (d, uid) => collection(d, 'friends', uid, 'meta');

/// cheers/{toUid}/from/{fromUid} — one MashaAllah per friend per recipient.
export const cheerRef = (d, toUid, fromUid) =>
  doc(d, 'cheers', toUid, 'from', fromUid);
export const cheersColl = (d, toUid) => collection(d, 'cheers', toUid, 'from');

/// inbox/{toUid}/items/{itemId} — a verse, an Eid greeting or an invitation.
export const inboxItemRef = (d, toUid, itemId) =>
  doc(d, 'inbox', toUid, 'items', itemId);
export const inboxColl = (d, toUid) => collection(d, 'inbox', toUid, 'items');

/// jumuah/{uid} — which masjid this Friday.
export const jumuahRef = (d, uid) => doc(d, 'jumuah', uid);

/// circle_codes/{code} and circles/{circleId}, with one progress document
/// per member underneath.
export const circleCodeRef = (d, code) => doc(d, 'circle_codes', code);
export const circlesColl = (d) => collection(d, 'circles');
export const circleRef = (d, circleId) => doc(d, 'circles', circleId);
export const circleProgressRef = (d, circleId, uid) =>
  doc(d, 'circles', circleId, 'progress', uid);
export const circleProgressColl = (d, circleId) =>
  collection(d, 'circles', circleId, 'progress');

// ── Round two: document shapes ────────────────────────────────────────────

/// A milestone as the profile holds it and the scoreboard copies it: one of
/// the six keys, and the day it was crossed. A real timestamp rather than
/// the server's clock, because the copy is republished long after that day.
export function milestone(
  key = 'streak100',
  at = new Date('2026-09-10T05:00:00Z'),
) {
  return { key, at: Timestamp.fromDate(at) };
}

/// What the publisher writes as progress.ramadan during the month.
export function ramadanShare(overrides = {}) {
  return {
    fasts: 12,
    fastingToday: true,
    taraweeh: false,
    date: '2027-02-20',
    ...overrides,
  };
}

/// What `FriendsActions.cheer` writes.
export function cheerDoc(key = 'streak100', overrides = {}) {
  return { milestone: key, at: serverTimestamp(), ...overrides };
}

/// The three inbox items, each with exactly its own keys.
export function verseItem(fromUid, overrides = {}) {
  return {
    type: 'verse',
    fromUid,
    fromName: 'Saad',
    at: serverTimestamp(),
    comfortId: 'anxious_1',
    ...overrides,
  };
}

export function eidItem(fromUid, overrides = {}) {
  return {
    type: 'eid',
    fromUid,
    fromName: 'Saad',
    at: serverTimestamp(),
    ...overrides,
  };
}

export function circleItem(fromUid, circleId, circleCode, overrides = {}) {
  return {
    type: 'circle',
    fromUid,
    fromName: 'Saad',
    at: serverTimestamp(),
    circleId,
    circleCode,
    ...overrides,
  };
}

/// What `FriendsActions.setJumuah` writes.
export function jumuahDoc(overrides = {}) {
  return {
    masjid: 'Masjid al-Rahman',
    date: '2026-09-18',
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

/// A circle as `CircleActions.create` writes it: the creator alone on the
/// members list, forty days, the code it will be joined by.
export function circleDoc(createdBy, code, overrides = {}) {
  return {
    name: 'Fajr for forty',
    goal: 'fajr',
    startsOn: '2026-09-15',
    days: 40,
    code,
    createdBy,
    members: [createdBy],
    createdAt: serverTimestamp(),
    ...overrides,
  };
}

/// One member's number.
export function circleProgressDoc(overrides = {}) {
  return { kept: 7, updatedAt: serverTimestamp(), ...overrides };
}

/// The "prayers together" baseline.
export function metaDoc(overrides = {}) {
  return {
    myStartTotal: 900,
    theirStartTotal: 1200,
    at: serverTimestamp(),
    ...overrides,
  };
}

// ── Round two: seeding (rules off) ────────────────────────────────────────

/// Both sides of a friendship at once. The names and codes are placeholders:
/// the list rule is not evaluated when seeding, and nothing in round two
/// reads them — only whether the entry exists.
export function seedFriends(env, a, b) {
  return env.withSecurityRulesDisabled(async (ctx) => {
    const d = db(ctx);
    await setDoc(listRef(d, a, b), {
      name: 'B',
      code: 'BBB222',
      since: serverTimestamp(),
    });
    await setDoc(listRef(d, b, a), {
      name: 'A',
      code: 'AAA222',
      since: serverTimestamp(),
    });
  });
}

/// A circle and the code document that names it, as one create leaves them.
export function seedCircle(env, circleId, createdBy, code, overrides = {}) {
  return env.withSecurityRulesDisabled(async (ctx) => {
    const d = db(ctx);
    await setDoc(circleRef(d, circleId), circleDoc(createdBy, code, overrides));
    await setDoc(circleCodeRef(d, code), { circleId });
  });
}

export function seedCircleProgress(env, circleId, uid, overrides = {}) {
  return env.withSecurityRulesDisabled((ctx) =>
    setDoc(
      circleProgressRef(db(ctx), circleId, uid),
      circleProgressDoc(overrides),
    ),
  );
}

export function seedJumuah(env, uid, overrides = {}) {
  return env.withSecurityRulesDisabled((ctx) =>
    setDoc(jumuahRef(db(ctx), uid), jumuahDoc(overrides)),
  );
}

export function seedCheer(env, toUid, fromUid, key = 'streak100') {
  return env.withSecurityRulesDisabled((ctx) =>
    setDoc(cheerRef(db(ctx), toUid, fromUid), cheerDoc(key)),
  );
}

export function seedInboxItem(env, toUid, itemId, data) {
  return env.withSecurityRulesDisabled((ctx) =>
    setDoc(inboxItemRef(db(ctx), toUid, itemId), data),
  );
}

export function seedMeta(env, uid, friendUid, overrides = {}) {
  return env.withSecurityRulesDisabled((ctx) =>
    setDoc(metaRef(db(ctx), uid, friendUid), metaDoc(overrides)),
  );
}
