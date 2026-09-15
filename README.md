# Layla · ليلى

**Stay connected with your prayers.**

Layla — a Flutter + Firebase prayer companion: accurate prayer times, Qibla, Tasbih,
Tahajjud with a privacy-safe live map, community stories, a two-step prayer
confirmation, and a streak that only counts prayers you actually confirmed.

---

## Quick start

Nothing is installed on a fresh Mac, so start here:

```bash
brew install --cask flutter
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```

Then, from this folder:

```bash
./setup.sh
```

That generates `android/` and `ios/`, applies Noor's manifest, `Info.plist` and
Kotlin soft-lock module, raises `minSdk` to 23, and runs `flutter pub get`.

Point it at Firebase:

```bash
flutterfire configure --project=<your-project> --platforms=android,ios
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Run it:

```bash
flutter run
```

Check it:

```bash
flutter analyze && flutter test
```

> **Not yet verified on device.** This codebase was written without a Flutter
> toolchain available, so it has never been compiled or run. Expect to fix a
> package-version constraint or two in `pubspec.yaml` on the first
> `flutter pub get` — the pinned versions are reasonable but not resolved
> against a live pub server.

---

## What is in here

| Path | What it holds |
|---|---|
| `lib/core/` | Theme, shared widgets, routing, services, utilities. Never imports a feature. |
| `lib/features/` | One folder per feature, layered `presentation → application → data → domain`. |
| `lib/shell/` | The five-tab bottom navigation frame. |
| `firebase/` | Firestore + Storage rules, indexes, and Cloud Functions (TypeScript). |
| `platform/` | `AndroidManifest.xml`, `Info.plist`, and the Kotlin prayer-lock module, copied into place by `setup.sh`. |
| `docs/` | Architecture, Firebase setup, and the prayer-lock limitations. |
| `test/` | Unit tests for the prayer engine, the geohash privacy layer, and formatting. |

Full specification, user flow, screen list, navigation map and database schema:
**[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)**.

---

## Three things worth knowing before you change anything

### 1. The prayer lock is native, and neither half is a hard lock

Blocking apps is impossible from Dart on both platforms. Both native routes are
written:

- **iOS — Apple Screen Time**. Live. Three app extensions in `ios/` are real
  Xcode targets embedded in Runner: `NoorDeviceActivityMonitor` (raises the
  shield on schedule while the app is closed), `NoorShield` (the gold-mark
  screen a blocked app shows) and `NoorWidgetsExtension`. All are signed with
  team `6RQYJNC9LM` under `com.adenzia.layla.*` and share App Group
  `group.com.adenzia.layla`. Development works today; TestFlight and the App
  Store need Apple's **Family Controls (Distribution)** approval for this team,
  requested at https://developer.apple.com/contact/request/family-controls-distribution.
- **Android — soft lock** (`platform/kotlin/`). A foreground service returns you
  to Noor when another app comes forward. Best-effort: OEM battery managers can
  stop it, and the user can always escape.

Both are **off by default** and need permissions the user grants deliberately.
Both can be switched off in seconds. What ships unconditionally on every device:
the full-screen **Prayer Focus** screen, prayer reminders, and a prayer that
does not count until it is confirmed.
Read **[`docs/PRAYER_LOCK_LIMITATIONS.md`](docs/PRAYER_LOCK_LIMITATIONS.md)**
before promising a user — or a store reviewer — anything else.

### 2. A prayer is completed only after the photo uploads

`PrayerStatus.awaitingProof` is not a completion. Cancel the picker, deny the
camera, kill the app, lose signal — the prayer stays unconfirmed, the focus
session stays open, and the streak does not move. The only path to
`completed` is `PrayerDayRepository.completeWithProof`, which requires a real
Storage path.

The photo is a **personal accountability record, not verification** — anyone
can photograph any mat. Its value is deliberate friction. Never describe it as
proof of worship.

### 3. The Tahajjud map never sees a precise location

Positions are reduced to a 5-character geohash (~5 km) and published as the
cell centre plus a stable per-user offset. `firestore.rules` rejects any
document carrying `lat`, `lng`, `accuracy`, `address` or `email`, and rejects a
geohash that is not exactly 5 characters. `test/geohash_test.dart` guards the
same promise from the Dart side.

---

## Design

One system merged from four reference designs: a night-navy ground with gold
line-art ornament, a **mihrab arch** as the signature shape, a per-prayer
gradient identity (Fajr deep blue → Dhuhr amber → Asr sky → Maghrib violet →
Isha navy → Tahajjud indigo-and-gold), Playfair Display for prayer names and
Inter with tabular numerals for everything that counts down.

Every visual is drawn in code — the night mosque, the lanterns, the compass
dial, the arch. There are no image assets to license, download or ship.

## Licence

Not set. Add one before publishing.
