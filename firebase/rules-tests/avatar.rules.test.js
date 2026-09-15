/**
 * Executable security-rules tests for the Layla Pro profile picture.
 *
 * The picture has nowhere to live but the document it belongs to: Firebase is
 * on the Spark plan, so there is no Storage bucket and no Cloud Function to
 * resize anything. It rides as a base64 JPEG in three places, under three
 * different ceilings, and firebase/firestore.rules is the only thing that
 * bounds any of them:
 *
 *   users/{uid}.photo       the 512-pixel picture the owner cropped, read by
 *                           its owner alone when the app opens.  200000 chars.
 *   users/{uid}.photoThumb  the 128-pixel copy, on the same private document.
 *                                                                 24000 chars.
 *   progress/{uid}.photo    that small copy published where friends can read
 *                           it, fetched once per friend every time a friends
 *                           list is opened.                        64000 chars.
 *
 * The numbers differ because a picture is not paid for once, it is paid for on
 * every read: the big one costs one person one download, and the small one is
 * multiplied by the length of a friends list and by how often it is opened.
 *
 * Runs against the real rules file, read off disk, beside friends.rules.test.js.
 *
 * Run with:   npm run emu     (starts the Firestore emulator, runs, shuts down)
 * or, against an emulator you already have running on 127.0.0.1:8080:
 *             npm test
 */
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  Bytes,
  deleteField,
  getDoc,
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
  progressDoc,
  progressRef,
  seedClaimedCode,
  seedListEntry,
  seedProgress,
  seedUser,
  userRef,
} from './support/env.js';

// The same people and codes as the Friends suite.
const ME = 'uid_me';
const THEM = 'uid_them';
const STRANGER = 'uid_stranger';

const MY_CODE = 'ABC234';
const THEIR_CODE = 'XYZ789';

/// A real JPEG — 1x1, 631 bytes — base64-encoded with no `data:` prefix,
/// which is exactly the string a phone sends and `Avatar.provider` decodes.
/// Only far smaller than a 256-pixel avatar, because nothing here turns on
/// what the pixels are.
const PHOTO =
  '/9j/4AAQSkZJRgABAQEAYABgAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRof' +
  'Hh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwh' +
  'MjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAAR' +
  'CAABAAEDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAA' +
  'AgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkK' +
  'FhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWG' +
  'h4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl' +
  '5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREA' +
  'AgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYk' +
  'NOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOE' +
  'hYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk' +
  '5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwD3+iiigD//2Q==';

// Each ceiling, and one character past it. What these decode to is not what
// the rules look at — the length is — so they are the cheapest strings of
// exactly the right size, in the base64 alphabet.
//
// The picture the owner keeps for themselves. 200000 is Avatar.maxChars.
const PHOTO_AT_CEILING = 'A'.repeat(200000);
const PHOTO_OVER_CEILING = 'A'.repeat(200001);

// The copy that gets published onward. 24000 is Avatar.thumbMaxChars.
const THUMB_AT_CEILING = 'A'.repeat(24000);
const THUMB_OVER_CEILING = 'A'.repeat(24001);

// The published copy on the scoreboard, whose ceiling did not move: 64000 is
// what it was before the picture grew and what it must still be, because
// 256-pixel pictures written by older builds are already stored under it.
//
// 64001 is therefore one number with two jobs. It is what the OLD rule refused
// on BOTH documents, so on users/{uid}.photo it must now be accepted — that is
// the regression proving the big ceiling moved — and on progress/{uid}.photo it
// must still be refused, proving the small one did not move with it.
const PUBLISHED_AT_CEILING = 'A'.repeat(64000);
const PUBLISHED_OVER_CEILING = 'A'.repeat(64001);

// Characters that are NOT base64 and weigh twice or four times what a ceiling
// budgets for. Rules `size()` counts UTF-16 code units, so each of these
// measures at or under the ceiling it is aimed at while being double it or
// worse on the wire — the charset clause, not the ceiling, is what refuses
// them, and there is one per field so that each field's clause is proved on
// its own.
const WIDE_TEXT = 'é'.repeat(64000);
const WIDE_EMOJI = '\u{1F600}'.repeat(32000);
const WIDE_TEXT_THUMB = 'é'.repeat(24000);

/// A complete profile write of the kind the app already makes, with no
/// picture anywhere in it. The regression guard's raw material: none of this
/// existed under any rule before the picture arrived, and all of it has to go
/// on passing untouched.
function ordinaryProfile(overrides = {}) {
  return {
    displayName: 'Aisha',
    friendCode: MY_CODE,
    settings: { theme: 'dark', adhanVoice: 'makkah' },
    location: { lat: 51.5074, lng: -0.1278, city: 'London' },
    stats: { totalPrayers: 900, streak: 3 },
    ...overrides,
  };
}

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
// MUST BE DENIED — every one of these is a picture nobody would be able to
// stop being read, over and over, if it got in.
// ═══════════════════════════════════════════════════════════════════════════
describe('pictures that must be refused', () => {
  test('1. a scoreboard picture one character past the ceiling is refused', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));

    await assertFails(
      setDoc(
        progressRef(d, ME),
        progressDoc(MY_CODE, { photo: PUBLISHED_OVER_CEILING }),
      ),
    );
  });

  test('2. a scoreboard picture that is not a string is refused', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));
    const p = progressRef(d, ME);

    // `is string` is doing real work here: without it a friend's phone gets
    // a number, a map or a list where it expects base64 and decodes nothing.
    await assertFails(setDoc(p, progressDoc(MY_CODE, { photo: 42 })));
    await assertFails(
      setDoc(p, progressDoc(MY_CODE, { photo: { bytes: PHOTO } })),
    );
    await assertFails(setDoc(p, progressDoc(MY_CODE, { photo: [PHOTO] })));
    await assertFails(setDoc(p, progressDoc(MY_CODE, { photo: true })));
  });

  test('3. a scoreboard still cannot carry a key outside the published set', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));

    // The picture widened `hasOnly` from ten keys to eleven and no further.
    // A twelfth key is refused exactly as the eleventh was before it — a
    // scoreboard is still not a place to smuggle a location or an email into.
    await assertFails(
      setDoc(
        progressRef(d, ME),
        progressDoc(MY_CODE, { photo: PHOTO, lat: 51.5 }),
      ),
    );
    await assertFails(
      setDoc(
        progressRef(d, ME),
        progressDoc(MY_CODE, { photo: PHOTO, email: 'aisha@example.com' }),
      ),
    );
  });

  test('4. a profile picture one character past the ceiling is refused', async () => {
    const d = db(fullAccount(env, ME));

    // On the way in…
    await assertFails(
      setDoc(userRef(d, ME), ordinaryProfile({ photo: PHOTO_OVER_CEILING })),
    );

    // …and onto a profile that is already there, by every shape of write the
    // app has: a merge and a field update.
    await seedUser(env, ME, ordinaryProfile());
    await assertFails(
      setDoc(userRef(d, ME), { photo: PHOTO_OVER_CEILING }, { merge: true }),
    );
    await assertFails(updateDoc(userRef(d, ME), { photo: PHOTO_OVER_CEILING }));
  });

  test('5. a profile picture that is not a string is refused', async () => {
    const d = db(fullAccount(env, ME));

    await assertFails(setDoc(userRef(d, ME), ordinaryProfile({ photo: 42 })));
    await assertFails(
      setDoc(userRef(d, ME), ordinaryProfile({ photo: { bytes: PHOTO } })),
    );
    await assertFails(setDoc(userRef(d, ME), ordinaryProfile({ photo: 3.5 })));

    // A Blob is the interesting one. Every other type above trips the rules up
    // on `size()`, which denies the write whether the type is checked or not —
    // but bytes have a size, so this is the only value that reaches the charset
    // clause by a route other than being a string. The app stores base64 text
    // and `Avatar.provider` decodes text; a Blob here renders nothing.
    await assertFails(
      setDoc(
        userRef(d, ME),
        ordinaryProfile({ photo: Bytes.fromUint8Array(new Uint8Array([1, 2, 3])) }),
      ),
    );
  });

  test('6. a stranger still cannot read a scoreboard that carries a picture', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedProgress(env, ME, MY_CODE, { photo: PHOTO });
    const d = db(fullAccount(env, STRANGER));

    // The picture is published to friends, and to nobody else — the read rule
    // is the same one it always was, and this is the thing it now guards.
    await assertFails(getDoc(progressRef(d, ME)));
  });

  test('7. a picture that is not base64 is refused, however it is measured', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));

    // Each of these passes the ceiling — 64000 code units — and is 128 KB of
    // bytes a friend's phone would download on every snapshot and decode into
    // nothing. The ceiling alone cannot tell them apart from a picture, which
    // is why the field is held to the base64 alphabet.
    await assertFails(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { photo: WIDE_TEXT })),
    );
    await assertFails(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { photo: WIDE_EMOJI })),
    );
    await assertFails(setDoc(userRef(d, ME), ordinaryProfile({ photo: WIDE_TEXT })));

    // And the short, obviously-not-base64 cases too, so that what reaches a
    // friend is at least something `Avatar.provider` can decode.
    await assertFails(
      setDoc(userRef(d, ME), ordinaryProfile({ photo: 'not!base64' })),
    );
    await assertFails(
      setDoc(
        userRef(d, ME),
        ordinaryProfile({ photo: `data:image/jpeg;base64,${PHOTO}` }),
      ),
    );
  });

  test('8. nobody can put a picture on somebody else’s profile', async () => {
    await seedUser(env, ME, ordinaryProfile());
    const d = db(fullAccount(env, STRANGER));

    await assertFails(
      setDoc(userRef(d, ME), { photo: PHOTO }, { merge: true }),
    );
    await assertFails(
      setDoc(userRef(d, ME), { photoThumb: PHOTO }, { merge: true }),
    );
  });

  test('9. a thumbnail one character past its own ceiling is refused', async () => {
    const d = db(fullAccount(env, ME));

    // 24000 is the number that matters most of the three, because this is the
    // copy that is fetched once per friend every time a friends list opens.
    // On the way in…
    await assertFails(
      setDoc(userRef(d, ME), ordinaryProfile({ photoThumb: THUMB_OVER_CEILING })),
    );

    // …and onto a profile that is already there, by both shapes of write the
    // cropper has.
    await seedUser(env, ME, ordinaryProfile());
    await assertFails(
      setDoc(userRef(d, ME), { photoThumb: THUMB_OVER_CEILING }, { merge: true }),
    );
    await assertFails(
      updateDoc(userRef(d, ME), { photoThumb: THUMB_OVER_CEILING }),
    );
  });

  test('10. a thumbnail that is not a string is refused', async () => {
    const d = db(fullAccount(env, ME));
    const u = userRef(d, ME);

    // Without `is string` the size clause is never reached, and a map or a
    // list of any weight at all rides through into the document that gets
    // copied out to every friend.
    await assertFails(setDoc(u, ordinaryProfile({ photoThumb: 42 })));
    await assertFails(setDoc(u, ordinaryProfile({ photoThumb: 3.5 })));
    await assertFails(
      setDoc(u, ordinaryProfile({ photoThumb: { bytes: PHOTO } })),
    );
    await assertFails(setDoc(u, ordinaryProfile({ photoThumb: [PHOTO] })));
    await assertFails(setDoc(u, ordinaryProfile({ photoThumb: true })));
    await assertFails(
      setDoc(
        u,
        ordinaryProfile({
          photoThumb: Bytes.fromUint8Array(new Uint8Array([1, 2, 3])),
        }),
      ),
    );
  });

  test('11. a thumbnail that is not base64 is refused, however it is measured', async () => {
    const d = db(fullAccount(env, ME));

    // 24000 accented letters measure exactly 24000 code units, so the ceiling
    // alone waves them through at 48000 bytes — twice the budget, on a field
    // read once per friend per list open, decoding into nothing at the far
    // end. The charset clause is what refuses it.
    await assertFails(
      setDoc(userRef(d, ME), ordinaryProfile({ photoThumb: WIDE_TEXT_THUMB })),
    );
    await assertFails(
      setDoc(userRef(d, ME), ordinaryProfile({ photoThumb: 'not!base64' })),
    );
    await assertFails(
      setDoc(
        userRef(d, ME),
        ordinaryProfile({ photoThumb: `data:image/jpeg;base64,${PHOTO}` }),
      ),
    );
  });

  test('12. the two fields are bounded separately, not as a pair', async () => {
    const d = db(fullAccount(env, ME));

    // Each half of the write has to stand on its own. A flawless 512-pixel
    // picture does not buy an oversized thumbnail past the clause that guards
    // the copy friends read…
    await assertFails(
      setDoc(
        userRef(d, ME),
        ordinaryProfile({
          photo: PHOTO_AT_CEILING,
          photoThumb: THUMB_OVER_CEILING,
        }),
      ),
    );

    // …and a perfectly small thumbnail does not buy an oversized picture past
    // the other one.
    await assertFails(
      setDoc(
        userRef(d, ME),
        ordinaryProfile({
          photo: PHOTO_OVER_CEILING,
          photoThumb: THUMB_AT_CEILING,
        }),
      ),
    );
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// MUST BE ALLOWED — the honest client. A failure here is a broken feature,
// and the last two are the guard that the new clause broke nothing.
// ═══════════════════════════════════════════════════════════════════════════
describe('the honest client', () => {
  test('a. publishes a scoreboard with a picture on it', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));

    await assertSucceeds(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { photo: PHOTO })),
    );

    // And republishes it when the picture changes, which is what makes the
    // publisher treat a changed picture as worth a write.
    await assertSucceeds(
      setDoc(
        progressRef(d, ME),
        progressDoc(MY_CODE, { photo: PUBLISHED_AT_CEILING, streak: 4 }),
      ),
    );
  });

  test('b. publishes a scoreboard with no picture, null or absent', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));

    // Nobody has set one: the publisher sends an explicit null…
    await assertSucceeds(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { photo: null })),
    );

    // …and every build that shipped before the picture existed sends a
    // document without the key at all, which has to go on working.
    await assertSucceeds(setDoc(progressRef(d, ME), progressDoc(MY_CODE)));
  });

  test('c. publishes a picture of exactly the ceiling', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));

    // 64000 is allowed on the scoreboard and 64001 is not: that boundary is
    // still exactly where it was said to be. The same string is nowhere near
    // the profile's own ceiling any more, and is allowed there too.
    await assertSucceeds(
      setDoc(
        progressRef(d, ME),
        progressDoc(MY_CODE, { photo: PUBLISHED_AT_CEILING }),
      ),
    );
    await assertSucceeds(
      setDoc(userRef(d, ME), ordinaryProfile({ photo: PUBLISHED_AT_CEILING })),
    );
  });

  test('d. lets a friend read a scoreboard picture', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedProgress(env, ME, MY_CODE, { photo: PHOTO });
    await seedListEntry(env, ME, THEM, 'Yusuf', THEIR_CODE);
    const d = db(fullAccount(env, THEM));

    const snap = await assertSucceeds(getDoc(progressRef(d, ME)));
    expect(snap.data().photo).toBe(PHOTO);
  });

  test('e. sets a picture on its own profile, and takes it off again', async () => {
    await seedUser(env, ME, ordinaryProfile());
    const d = db(fullAccount(env, ME));

    // What AvatarController.pickAndSave writes.
    await assertSucceeds(
      setDoc(userRef(d, ME), { photo: PHOTO }, { merge: true }),
    );

    // And what remove() writes, either way round it is written: the null the
    // controller sends, and the deletion that would do the same job.
    await assertSucceeds(
      setDoc(userRef(d, ME), { photo: null }, { merge: true }),
    );
    await assertSucceeds(
      setDoc(userRef(d, ME), { photo: PHOTO }, { merge: true }),
    );
    await assertSucceeds(updateDoc(userRef(d, ME), { photo: deleteField() }));
  });

  test('f. lets a guest set a picture on their own profile', async () => {
    // users/{uid} asks for isOwner, not isFullAccount — a guest's profile is
    // their own and nobody else can read it, so the picture is theirs to set.
    // Publishing it to friends is the part a guest cannot reach; the code is
    // seeded so that being a guest is the only thing refusing that half.
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(guestAccount(env, ME));

    await assertSucceeds(
      setDoc(userRef(d, ME), { photo: PHOTO }, { merge: true }),
    );
    await assertFails(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { photo: PHOTO })),
    );
  });

  test('g. writes a display name on its own, with no picture key at all', async () => {
    // The regression guard. users/{uid} had no field validation whatsoever
    // before the ceiling arrived, and the ceiling must not have turned an
    // ordinary profile write into a shape the rules have an opinion about.
    await seedUser(env, ME, ordinaryProfile());
    const d = db(fullAccount(env, ME));

    await assertSucceeds(
      setDoc(userRef(d, ME), { displayName: 'Aisha K' }, { merge: true }),
    );
    await assertSucceeds(updateDoc(userRef(d, ME), { displayName: 'Aisha' }));
    await assertSucceeds(
      updateDoc(userRef(d, ME), { friendCode: deleteField() }),
    );
  });

  test('h. makes every other profile write it made before, untouched', async () => {
    const d = db(fullAccount(env, ME));

    // Creating the whole profile from nothing, the way sign-up does.
    await assertSucceeds(setDoc(userRef(d, ME), ordinaryProfile()));

    // Then each field the app touches on its own, and all of them at once —
    // none of these carries a 'photo' key, and none of them may start needing
    // one. The last write goes over a profile that DOES have a picture on it,
    // because a merge is evaluated against the document it produces: an
    // ordinary write must not be refused for a picture it never mentioned.
    await assertSucceeds(
      setDoc(userRef(d, ME), { settings: { theme: 'light' } }, { merge: true }),
    );
    await assertSucceeds(
      setDoc(
        userRef(d, ME),
        { location: { lat: 21.4225, lng: 39.8262, city: 'Makkah' } },
        { merge: true },
      ),
    );
    await assertSucceeds(
      setDoc(userRef(d, ME), { stats: { streak: 4 } }, { merge: true }),
    );

    await assertSucceeds(
      setDoc(userRef(d, ME), { photo: PHOTO }, { merge: true }),
    );
    await assertSucceeds(
      setDoc(
        userRef(d, ME),
        { displayName: 'Aisha K', stats: { streak: 5 } },
        { merge: true },
      ),
    );
  });

  test('i. stores both copies at exactly their own ceilings', async () => {
    await seedUser(env, ME, ordinaryProfile());
    const d = db(fullAccount(env, ME));

    // 200000 is allowed and 200001 is not; 24000 is allowed and 24001 is not.
    // Both boundaries are where they are said to be, and both are written in
    // the single merge the cropper makes when it saves a crop.
    await assertSucceeds(
      setDoc(
        userRef(d, ME),
        { photo: PHOTO_AT_CEILING, photoThumb: THUMB_AT_CEILING },
        { merge: true },
      ),
    );
    await assertFails(
      setDoc(userRef(d, ME), { photo: PHOTO_OVER_CEILING }, { merge: true }),
    );
    await assertFails(
      setDoc(userRef(d, ME), { photoThumb: THUMB_OVER_CEILING }, { merge: true }),
    );
  });

  test('j. writes a thumbnail that is null, or absent altogether', async () => {
    const d = db(fullAccount(env, ME));

    // Absent: every build that shipped before the crop existed writes profiles
    // with no photoThumb key at all, and they have to go on being written.
    await assertSucceeds(setDoc(userRef(d, ME), ordinaryProfile()));
    await assertSucceeds(
      setDoc(userRef(d, ME), ordinaryProfile({ photo: PHOTO })),
    );

    // Null, and the deletion that would do the same job — taking a picture off
    // has to be as ordinary as putting one on, on both fields at once, which
    // is exactly the write remove() makes.
    await assertSucceeds(
      setDoc(userRef(d, ME), { photoThumb: null }, { merge: true }),
    );
    await assertSucceeds(
      setDoc(
        userRef(d, ME),
        { photo: null, photoThumb: null },
        { merge: true },
      ),
    );
    await assertSucceeds(
      updateDoc(userRef(d, ME), { photoThumb: deleteField() }),
    );
  });

  test('k. saves a crop and publishes the small copy, the way the app does', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    await seedUser(env, ME, ordinaryProfile());
    const d = db(fullAccount(env, ME));

    // The whole round trip in the order the cropper makes it: both JPEGs onto
    // the private profile in one merge, then the small one — and only the
    // small one — out onto the scoreboard friends read.
    await assertSucceeds(
      setDoc(
        userRef(d, ME),
        { photo: PHOTO, photoThumb: PHOTO },
        { merge: true },
      ),
    );
    await assertSucceeds(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { photo: PHOTO })),
    );

    // And taking it off again: null on both private fields, null on the
    // published one.
    await assertSucceeds(
      setDoc(
        userRef(d, ME),
        { photo: null, photoThumb: null },
        { merge: true },
      ),
    );
    await assertSucceeds(
      setDoc(progressRef(d, ME), progressDoc(MY_CODE, { photo: null })),
    );

    const snap = await assertSucceeds(getDoc(userRef(d, ME)));
    expect(snap.data().photoThumb).toBe(null);
  });
});

// ═══════════════════════════════════════════════════════════════════════════
// THE CEILINGS MOVED APART — the picture the owner keeps grew to 512 pixels
// and the copy friends read did not. One number proves both halves of that:
// 64001 characters, which the old shared rule refused everywhere.
// ═══════════════════════════════════════════════════════════════════════════
describe('the two ceilings moved apart', () => {
  test('m. a profile picture of 64001, which the old rule refused, is stored', async () => {
    const d = db(fullAccount(env, ME));

    // This is the regression. Under the old rule this exact write was denied,
    // on this exact document — if the ceiling had not really moved, this test
    // would be the one that failed, and a 512-pixel crop would come back from
    // the server as permission-denied on the owner's own private profile.
    await assertSucceeds(
      setDoc(userRef(d, ME), ordinaryProfile({ photo: PUBLISHED_OVER_CEILING })),
    );
    await assertSucceeds(
      setDoc(
        userRef(d, ME),
        { photo: PUBLISHED_OVER_CEILING },
        { merge: true },
      ),
    );
  });

  test('n. the published copy still refuses 64001, exactly as it always did', async () => {
    await seedClaimedCode(env, ME, MY_CODE, 'Aisha');
    const d = db(fullAccount(env, ME));

    // The other half, and the more important one. Raising the private ceiling
    // must not have dragged the published one up with it: this is the field
    // every friend downloads on every snapshot, and the same string that is
    // now welcome on the profile is still refused here.
    await assertFails(
      setDoc(
        progressRef(d, ME),
        progressDoc(MY_CODE, { photo: PUBLISHED_OVER_CEILING }),
      ),
    );

    // 64000 is still fine on it, so what moved is the boundary's far side and
    // nothing else.
    await assertSucceeds(
      setDoc(
        progressRef(d, ME),
        progressDoc(MY_CODE, { photo: PUBLISHED_AT_CEILING }),
      ),
    );
  });

  test('n2. 24000 is the thumbnail ceiling, not 64000', async () => {
    const d = db(fullAccount(env, ME));

    // The thumbnail did not inherit the old shared number either. A string the
    // scoreboard would accept is far too big for the field that feeds it.
    await assertFails(
      setDoc(
        userRef(d, ME),
        ordinaryProfile({ photoThumb: PUBLISHED_AT_CEILING }),
      ),
    );
    await assertSucceeds(
      setDoc(userRef(d, ME), ordinaryProfile({ photoThumb: THUMB_AT_CEILING })),
    );
  });

  test('o. an ordinary profile write is still no business of the rules', async () => {
    // Two clauses now sit on users/{uid} where one sat before. Neither may
    // have turned a write that mentions no picture into a shape the rules
    // have an opinion about — a display name on its own is the plainest one
    // the app makes, and the seed write at sign-up carries neither key.
    await seedUser(env, ME, ordinaryProfile());
    const d = db(fullAccount(env, ME));

    await assertSucceeds(
      setDoc(userRef(d, ME), { displayName: 'Aisha K' }, { merge: true }),
    );
    await assertSucceeds(updateDoc(userRef(d, ME), { displayName: 'Aisha' }));

    // The sign-up write itself, onto a profile that does not exist yet.
    const fresh = db(fullAccount(env, STRANGER));
    await assertSucceeds(setDoc(userRef(fresh, STRANGER), ordinaryProfile()));
  });
});
