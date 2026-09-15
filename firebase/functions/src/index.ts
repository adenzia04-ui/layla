import { initializeApp } from "firebase-admin/app";
import { FieldPath, FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import * as functionsV1 from "firebase-functions/v1";
import { onDocumentCreated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions";

initializeApp();
const db = getFirestore();

const OBLIGATORY = ["fajr", "dhuhr", "asr", "maghrib", "isha"] as const;
const REPORT_THRESHOLD = 3;

/** "2026-08-20" for a Date, in UTC — matches the client's day-document ids. */
function dayId(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function previousDayId(id: string): string {
  const date = new Date(`${id}T00:00:00Z`);
  date.setUTCDate(date.getUTCDate() - 1);
  return dayId(date);
}

/* ────────────────────────────────────────────────────────────────────────
 * 1. Seed a profile the moment an account is created.
 * ──────────────────────────────────────────────────────────────────────── */
export const onUserCreated = functionsV1.auth.user().onCreate(async (user) => {
  // `UserRecord` has no `isAnonymous`; an anonymous sign-in is one with no
  // linked providers. Guests keep their uid when they later upgrade, which is
  // what preserves their streak.
  const isAnonymous = user.providerData.length === 0;

  await db.doc(`users/${user.uid}`).set(
    {
      displayName: user.displayName ?? (isAnonymous ? "Guest" : ""),
      email: user.email ?? "",
      isAnonymous,
      createdAt: FieldValue.serverTimestamp(),
      settings: {
        calculationMethod: "muslim_world_league",
        madhab: "shafi",
        adjustments: {},
        notifications: {},
        lockEnabled: true,
        tahajjudVisible: false,
        use24hClock: false,
      },
      stats: {
        currentStreak: 0,
        longestStreak: 0,
        totalPrayers: 0,
        totalTahajjud: 0,
        lastCompletedDate: null,
      },
    },
    { merge: true },
  );
});

/* ────────────────────────────────────────────────────────────────────────
 * 2. Remove everything a deleted account owns.
 *    Prayer-mat photos are personal; they must not outlive the account.
 * ──────────────────────────────────────────────────────────────────────── */
export const onUserDeleted = functionsV1.auth.user().onDelete(async (user) => {
  const uid = user.uid;

  await db.recursiveDelete(db.doc(`users/${uid}`));
  await db.doc(`tahajjud_presence/${uid}`).delete().catch(() => undefined);

  const stories = await db.collection("stories").where("uid", "==", uid).get();
  await Promise.all(stories.docs.map((doc) => db.recursiveDelete(doc.ref)));

  // Friends: the shared scoreboard, the code, and the entry on every
  // friend's list — the client cannot delete the first two (rules refuse
  // it), and a stale code would otherwise let strangers befriend a ghost.
  const list = await db.collection(`friends/${uid}/list`).get();
  await Promise.all(
    list.docs.map((doc) =>
      db.doc(`friends/${doc.id}/list/${uid}`).delete().catch(() => undefined),
    ),
  );
  await db.recursiveDelete(db.doc(`friends/${uid}`));
  await db.doc(`progress/${uid}`).delete().catch(() => undefined);
  const codes = await db.collection("friend_codes").where("uid", "==", uid).get();
  await Promise.all(codes.docs.map((doc) => doc.ref.delete()));
  // The write-once marker that says this account claimed its code. The client
  // can never remove it — that is what stops an account claiming a second
  // code — so it would outlive the account and leave a uid that can never
  // claim one again if that uid were ever reissued.
  await db.doc(`friend_code_owners/${uid}`).delete().catch(() => undefined);

  await getStorage()
    .bucket()
    .deleteFiles({ prefix: `prayer_proofs/${uid}/` })
    .catch((error) => logger.warn("proof cleanup failed", { uid, error }));

  logger.info("account data removed", { uid });
});

/* ────────────────────────────────────────────────────────────────────────
 * 3. Authoritative streak recalculation.
 *
 *    The client updates stats optimistically so the UI is instant. This
 *    function is the source of truth: it walks backwards from the most
 *    recent complete day, so a wrong device clock or a failed write cannot
 *    inflate a streak.
 * ──────────────────────────────────────────────────────────────────────── */
export const recalculateStreak = onDocumentWritten(
  "users/{uid}/prayer_days/{date}",
  async (event) => {
    const uid = event.params.uid as string;
    const after = event.data?.after.data();
    if (!after) return;

    // Recount from the document itself rather than trusting `completedCount`.
    const prayers = (after.prayers ?? {}) as Record<string, { status?: string }>;
    const completedCount = OBLIGATORY.filter(
      (key) => prayers[key]?.status === "completed",
    ).length;
    const isComplete = completedCount === OBLIGATORY.length;

    if (
      after.completedCount !== completedCount ||
      after.isComplete !== isComplete
    ) {
      await event.data!.after.ref.set(
        { completedCount, isComplete },
        { merge: true },
      );
    }

    const days = await db
      .collection(`users/${uid}/prayer_days`)
      .orderBy(FieldPath.documentId(), "desc")
      .limit(400)
      .get();

    const completeDays = new Set<string>();
    let totalPrayers = 0;
    let totalTahajjud = 0;

    for (const doc of days.docs) {
      const data = doc.data();
      const dayPrayers = (data.prayers ?? {}) as Record<
        string,
        { status?: string }
      >;
      const count = OBLIGATORY.filter(
        (key) => dayPrayers[key]?.status === "completed",
      ).length;
      totalPrayers += count;
      if (count === OBLIGATORY.length) completeDays.add(doc.id);
      if (data.tahajjud?.prayed === true) totalTahajjud += 1;
    }

    // Current streak: consecutive complete days ending today or yesterday.
    const today = dayId(new Date());
    const yesterday = previousDayId(today);
    let cursor = completeDays.has(today)
      ? today
      : completeDays.has(yesterday)
        ? yesterday
        : null;

    let currentStreak = 0;
    while (cursor && completeDays.has(cursor)) {
      currentStreak += 1;
      cursor = previousDayId(cursor);
    }

    // Longest streak: scan every complete day in order.
    const sorted = [...completeDays].sort();
    let longestStreak = 0;
    let run = 0;
    let previous: string | null = null;
    for (const id of sorted) {
      run = previous !== null && previousDayId(id) === previous ? run + 1 : 1;
      longestStreak = Math.max(longestStreak, run);
      previous = id;
    }

    await db.doc(`users/${uid}`).set(
      {
        stats: {
          currentStreak,
          longestStreak,
          totalPrayers,
          totalTahajjud,
          lastCompletedDate: sorted.length > 0 ? sorted[sorted.length - 1] : null,
        },
      },
      { merge: true },
    );
  },
);

/* ────────────────────────────────────────────────────────────────────────
 * 4. Sweep expired Tahajjud presences.
 *
 *    Clients filter on expiresAt too, so a ghost is never *shown* — this
 *    keeps the collection from growing without bound when an app is killed
 *    mid-session.
 * ──────────────────────────────────────────────────────────────────────── */
export const expireTahajjudPresence = onSchedule(
  { schedule: "every 5 minutes", timeZone: "UTC" },
  async () => {
    const expired = await db
      .collection("tahajjud_presence")
      .where("expiresAt", "<", Timestamp.now())
      .limit(500)
      .get();

    if (expired.empty) return;

    const batch = db.batch();
    expired.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    logger.info("expired presences removed", { count: expired.size });
  },
);

/* ────────────────────────────────────────────────────────────────────────
 * 5. Moderation: count reports and hide a story at the threshold.
 *    Clients can never write `status` themselves (see firestore.rules).
 * ──────────────────────────────────────────────────────────────────────── */
export const onStoryReported = onDocumentCreated(
  "reports/{reportId}",
  async (event) => {
    const storyId = event.data?.data().storyId as string | undefined;
    if (!storyId) return;

    const storyRef = db.doc(`stories/${storyId}`);

    await db.runTransaction(async (tx) => {
      const story = await tx.get(storyRef);
      if (!story.exists) return;

      const reportCount = ((story.data()?.reportCount as number) ?? 0) + 1;
      const update: Record<string, unknown> = { reportCount };

      if (
        reportCount >= REPORT_THRESHOLD &&
        story.data()?.status === "published"
      ) {
        update.status = "under_review";
        update.hiddenAt = FieldValue.serverTimestamp();
      }
      tx.set(storyRef, update, { merge: true });
    });
  },
);

/* ────────────────────────────────────────────────────────────────────────
 * 6. Close out yesterday: anything still pending or awaiting a photo is
 *    marked missed, so the history is honest rather than perpetually open.
 * ──────────────────────────────────────────────────────────────────────── */
export const closeOutPreviousDay = onSchedule(
  { schedule: "every day 03:00", timeZone: "UTC" },
  async () => {
    const target = previousDayId(dayId(new Date()));
    const days = await db
      .collectionGroup("prayer_days")
      .where("date", "==", target)
      .where("isComplete", "==", false)
      .limit(500)
      .get();

    await Promise.all(
      days.docs.map(async (doc) => {
        const prayers = (doc.data().prayers ?? {}) as Record<
          string,
          { status?: string }
        >;
        const update: Record<string, unknown> = {};
        for (const key of OBLIGATORY) {
          const status = prayers[key]?.status;
          if (status !== "completed" && status !== "missed") {
            update[`prayers.${key}.status`] = "missed";
          }
        }
        if (Object.keys(update).length > 0) await doc.ref.update(update);
      }),
    );
  },
);
