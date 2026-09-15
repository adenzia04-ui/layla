# Prayer Lock — what is actually possible

Read this before you promise anything to users or to a store reviewer.

## The claim to avoid

> "During prayer time, Noor blocks all other apps on your phone."

This is **false for the app as it stands today**, on both platforms. Flutter and Firebase have nothing to do with it — this is an operating-system capability question, and on both platforms it is answered by native code plus permissions the user grants outside your app.

It can be made *conditionally* true, and the two platforms get there by completely different routes:

- **iOS** — possible, via Apple's Screen Time API (`FamilyControls` + `ManagedSettings` + `DeviceActivity`). This is how Opal, one sec, Jomo and ScreenZen work. **Live in Layla Pro**: the targets are in `ios/` (`NoorDeviceActivityMonitor`, `NoorShield`) and the shield works on a development build. App Store distribution still waits on Apple's Family Controls (Distribution) approval for team 6RQYJNC9LM, requested 16 Sep 2026.
- **Android** — possible in a weaker, best-effort form, via a foreground service plus two special-access permissions. **Implemented in Noor v1**, off by default.

Neither is a hard lock. Both can be turned off by the user in seconds. Ship the claim above and you will get rejected, or get users who feel lied to.

---

## iOS

**Correction to an earlier version of this document:** app blocking on iOS *is*
possible. It is not something a Flutter app can do on its own, and it is not
something you can turn on by shipping an update — but the API exists and
several well-known focus apps use it.

### What actually works: the Screen Time API

Since iOS 16, `FamilyControls` supports **individual authorisation**
(`AuthorizationCenter.shared.requestAuthorization(for: .individual)`), which
lets an app shield apps on *its own device, for its own user* — self-imposed
focus, not parental control. Combined with `ManagedSettings` and
`DeviceActivity` this gives a genuine block: shielded apps open to an Apple
system screen instead of their content.

What it costs:

| Requirement | Detail |
|---|---|
| **Family Controls (Distribution) entitlement** | Requested from Apple through a form, reviewed by hand. Granted to legitimate screen-time and focus products. Not guaranteed, and not instant. |
| **Native Swift, not Dart** | You need a `DeviceActivityMonitor` app extension, usually a `ShieldConfiguration` extension for custom branding, an App Group to share state, and a `MethodChannel` to drive it from Flutter. |
| **iOS 16+** | `.individual` authorisation is unavailable before that. Older devices fall back to focus-screen-only. |
| **You never learn which apps** | The user chooses them in Apple's own `FamilyActivityPicker`; your app receives opaque `ApplicationToken`s it cannot inspect, log, or send anywhere. Good for privacy, but it means Noor cannot pre-select "social media" for the user. |
| **Local scheduling only** | Windows are registered as a `DeviceActivitySchedule` on-device. You cannot start a shield from a server, a push, or a Firestore document. Prayer times are computed locally anyway, so re-registering tomorrow's five windows each day works — but it is your code's job, and the app must run often enough to do it. |
| **The user can undo it** | They can revoke Screen Time authorisation, or delete the app. A shield is friction, not a cage. |

### What does not work on iOS, under any entitlement

| Approach | Verdict |
|---|---|
| Detect *where* the user went | No API. `AppLifecycleState.paused` tells you they left, nothing more. |
| Force Noor back to the foreground | No API. Apps cannot self-activate. |
| Guided Access / Single App Mode | User-initiated (triple-click) or MDM-supervised only. Not programmatic. |
| Enable a Focus mode | Your app can *suggest* a Focus filter; it cannot switch one on. |
| Drive any of it from your backend | Screen Time is device-local by design. |

### What Noor ships on iOS

The Screen Time integration **is built and running** — `ios/` holds the bridge,
the shared shield helper, the `DeviceActivityMonitor` extension and the shield
UI extension. It is dormant until two things happen, neither of which is code:

1. Apple grants the **Family Controls (Distribution)** entitlement.
2. The two extension targets and the App Group are added in Xcode, and
   `NoorScreenTimeEnabled` is flipped to `true` in `Info.plist`.

The Xcode targets already exist. Until Apple approves distribution, `permissions()`
honestly reports `supported: false`, the settings screen reads "Not available
on this device", and nothing crashes.

**How it works once enabled**

| Piece | Job |
|---|---|
| `PrayerLockBridge.swift` | Answers the same MethodChannel as Android. Authorisation, Apple's app picker, schedule registration, immediate raise/drop. |
| `NoorLockShared.swift` | The App Group defaults and the named `ManagedSettingsStore`. The only channel between the app and its extensions. |
| `NoorDeviceActivityMonitor` | Woken by iOS at each window's edges. Raises the shield at the start, drops it at the end — **while Noor is closed**. |
| `NoorShield` | Replaces Apple's grey default with "It is time for Maghrib" in Noor's own colours. |
| `prayerLockSyncProvider` (Dart) | Re-registers the day's five windows whenever the computed times change. |

**What still holds true, entitlement or not**

- Noor never learns which apps were chosen. iOS hands back opaque tokens.
- The schedule is device-local. Firebase cannot raise or drop a shield.
- The shield drops the instant the prayer is confirmed, and always at the end
  of the 30 minutes — a missed prayer does not hold the phone hostage.
- The user can revoke Screen Time in Settings at any moment. **This is friction
  the user chose, not a cage.** The streak is still the real enforcement.

---

## Android

Possible, in layers, each with a real cost:

| Layer | Permission | Cost |
|---|---|---|
| Foreground service holding the session | `FOREGROUND_SERVICE` + `POST_NOTIFICATIONS` | persistent notification (required, not optional) |
| Full-screen intent that opens Focus over the lock screen | `USE_FULL_SCREEN_INTENT` | Android 14+ requires user grant; auto-granted only to calling/alarm apps |
| Exact alarms at prayer time | `SCHEDULE_EXACT_ALARM` | Android 12+; user grants in Settings; Doze can still delay |
| Detect that a *different* app is in the foreground | `PACKAGE_USAGE_STATS` (special access) | user must enable it in Settings → Special app access → Usage access. **Play Store treats it as a restricted permission and requires justification.** |
| Draw the focus screen over that app | `SYSTEM_ALERT_WINDOW` | separate Settings toggle; Android 12+ blocks overlays over some system UI |
| Instant app-switch detection instead of polling | `AccessibilityService` | **Play Store's most restricted API.** Using it for non-accessibility purposes is a common rejection reason. Noor does not use it. |

Even with everything granted: OEM battery managers (Xiaomi, Oppo, Samsung) kill background services; the user can force-stop Noor, revoke the toggles, reboot, or use Safe Mode.

**Therefore on Android, Noor ships** the same in-app Focus screen, plus an **optional soft lock** the user turns on explicitly in Profile → Settings, with plain-language disclosure of both permissions and a one-tap disable. Implementation: `android/app/src/main/kotlin/.../PrayerLockService.kt`, reached through a `MethodChannel` behind the `PrayerLockPlatform` interface, so iOS gets a no-op and the Dart code never branches on platform.

---

## The mat photo — what it is and isn't

The two-step confirmation *is* fully implementable, and Noor implements it exactly as specified: Step 1 records intent, Step 2 requires a photo, and `status` becomes `completed` only after the upload succeeds. Cancel, background, kill the app, deny the camera — the prayer stays unconfirmed and the focus session stays active.

Be straight with users about what the photo means: it is a **personal accountability record**, not verification. Nothing stops someone photographing any prayer mat, or the same one twice. Its value is deliberate friction and a private visual diary — not proof, and it must never be described as proof of worship to Allah. Two consequences for the build:

- **Privacy.** Photos may show a person's home. `prayer_proofs/{uid}/**` is readable only by its owner — no public URLs, no admin browsing UI, no sharing feature. Downloads use short-lived signed access through the SDK.
- **Storage cost.** 5 photos/user/day at ~250 KB ≈ 450 MB per user per year. Compress to `imageQuality: 60`, `maxWidth: 1280`, and add a Cloud Function or lifecycle rule to delete proofs older than 90 days.
