# iOS prayer lock — Xcode setup

Everything in `platform/ios/` is written and ready. What a script cannot do is
edit `Runner.xcodeproj`: app extensions, App Groups and entitlements have to be
added in Xcode. This is that checklist, in order.

**The app builds and runs fine without any of it.** Until step 6 flips the
plist flag, `permissions()` reports `supported: false`, the settings screen
reads "Not available on this device", and Noor falls back to the focus screen
and the streak. Nothing crashes and nothing lies.

---

## 0. Request the entitlement first — it gates everything

Apple must grant **Family Controls (Distribution)** before a build using it can
be signed for TestFlight or the App Store.

1. https://developer.apple.com/contact/request/family-controls-distribution
2. Describe Noor accurately: a prayer app that pauses apps the user themselves
   chose, during the 30 minutes after each prayer begins, using `.individual`
   authorisation. Say plainly that it is self-imposed focus, not parental
   control.
3. Reviewed by hand. Expect days to weeks. **Do this before writing any more
   code** — steps 1–7 are an afternoon, the approval is not.

You can develop and test on a physical device with a personal team in the
meantime; the entitlement is enforced at distribution signing.

---

## 1. App Group

Xcode → **Runner** target → *Signing & Capabilities* → **+ Capability** →
**App Groups** → add `group.com.SMAG.noor`.

If you change the identifier, change it in `NoorLockShared.swift` too — the
app and both extensions find each other through this string and nothing else.

## 2. Family Controls capability

Same panel → **+ Capability** → **Family Controls**.

This writes `com.apple.developer.family-controls` into
`ios/Runner/Runner.entitlements`, which `setup.sh` has already placed for you.

## 3. Add the DeviceActivity monitor extension — *required*

> **Already done.** This target now exists in `Runner.xcodeproj`, created
> programmatically rather than through the Xcode GUI, with its sources in
> `ios/NoorDeviceActivityMonitor/`. The steps below are kept only for
> rebuilding from scratch after regenerating `ios/`.
>
> Two things bit us and are easy to miss if you redo it by hand:
> - `PRODUCT_NAME` must be `$(TARGET_NAME)`. Without it the product builds as
>   a nameless `.appex` and Xcode fails with *"Multiple commands produce
>   '…/.appex'"*, which does not sound like a naming problem at all.
> - `CFBundleShortVersionString` and `CFBundleVersion` must match the host app
>   exactly. A mismatch makes iOS reject the extension **silently** — this is
>   how the widgets went missing once before.

**File → New → Target… → Device Activity Monitor Extension**

| Field | Value |
|---|---|
| Product Name | `NoorDeviceActivityMonitor` |
| Bundle Identifier | `com.SMAG.noor.NoorDeviceActivityMonitor` |
| Embed in | Runner |

Then:

1. Delete the stub Swift file Xcode generated.
2. Drag in `platform/ios/NoorDeviceActivityMonitor/NoorDeviceActivityMonitor.swift`.
3. Replace the generated `Info.plist` with the one in that folder.
4. Replace the generated `.entitlements` with the one in that folder.
5. Signing & Capabilities → add **App Groups** (`group.com.SMAG.noor`) and
   **Family Controls**.
6. Set the target's **Minimum Deployment** to **iOS 16.0**.

This target is what makes the lock work while Noor is closed. Skip it and the
shield only ever rises when the app happens to be running.

## 4. Add the shield UI extension — *optional but recommended*

**File → New → Target… → Shield Configuration Extension**

| Field | Value |
|---|---|
| Product Name | `NoorShield` |
| Bundle Identifier | `com.SMAG.noor.NoorShield` |

Same six steps, using `platform/ios/NoorShield/`.

Without it the block still works — it just shows Apple's grey default screen
instead of Noor's "It is time for Maghrib".

## 5. Share `NoorLockShared.swift` with all three targets

`setup.sh` copies it to `ios/NoorShared/NoorLockShared.swift`. Select it in
Xcode, open the **File Inspector** (⌥⌘1), and tick **all three** boxes under
*Target Membership*:

- [x] Runner
- [x] NoorDeviceActivityMonitor
- [x] NoorShield

This is the step people forget. Miss it and you get
`cannot find 'NoorLock' in scope` in whichever target you left unticked.

## 5b. Add the bridge to the Runner target

`setup.sh` staged two files into `ios/Runner/` that Xcode does not know about
yet, because dropping a file in the folder does not add it to the target:

- `PrayerLockBridge.swift`
- `NoorLockShared.swift` (also needs the two extension targets ticked — step 5)

Drag both into the **Runner** group in Xcode, ticking Runner under
*Target Membership*.

## 6. Turn the feature on

Two switches, both required:

1. **Runner target → Build Settings → Swift Compiler – Custom Flags →
   Active Compilation Conditions** → add `NOOR_SCREEN_TIME`.
   Without it `PrayerLockBridge.swift` compiles to nothing and `AppDelegate`
   answers the channel with the "unsupported" stub — which is exactly what
   makes a plain `flutter run` work before you do any of this.
2. `ios/Runner/Info.plist` → set `NoorScreenTimeEnabled` to `<true/>`.

Do this only once the entitlement is on your provisioning profile. It is the
switch between "the settings screen offers app pausing" and "the settings
screen says it is unavailable".

## 7. Raise the iOS deployment target

Runner target → Minimum Deployment → **iOS 16.0**, and the same in
`ios/Podfile` (`platform :ios, '16.0'`), then `cd ios && pod install`.

`.individual` Screen Time authorisation does not exist before iOS 16.

---

## Testing it

Screen Time behaves oddly in the Simulator — **test on a real device**.

1. Run on device. Profile → Reminders & focus → *Pause apps during prayer*.
2. Tap **Allow** — Apple's Screen Time prompt appears. Approve it.
3. Tap **Choose** — Apple's picker appears. Pick something harmless you can
   open, like Weather.
4. Force a window: temporarily shift a prayer with the **Manual adjustments**
   in Prayer settings so one starts a couple of minutes from now.
5. Wait for the window to open, then try to open the app you picked. You should
   get Noor's shield screen.
6. Confirm the prayer in Noor (both steps). The shield should lift immediately.

Reset between runs: Settings → Screen Time → *Turn off*, then delete the app.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `cannot find 'NoorLock' in scope` | Step 5 / 5b — target membership not ticked. |
| `cannot find 'PrayerLockBridge' in scope` | Step 5b — the file is in the folder but not in the target. |
| Settings still says "Not available" after all this | Step 6 — one of the two switches is missing. Both are needed. |
| Authorisation prompt never appears | Missing entitlement, or `NoorScreenTimeEnabled` still false. |
| Shield never rises | Monitor extension missing, not embedded, or its deployment target is below iOS 16. |
| Shield rises but looks like a system default | The `NoorShield` extension is missing — expected if you skipped step 4. |
| `startMonitoring` throws | Interval shorter than 15 minutes, or an activity with the same name is already running. `NoorLock.registerWindows` stops Noor's own activities first, so this usually means a stale build. |
| Works in debug, fails on TestFlight | The distribution entitlement is not on the profile. Back to step 0. |

---

# Widgets & Live Activity — Xcode setup

**No paid Apple account needed.** An earlier draft of this used an App Group to
pass data from the app to the widgets, which does not work on a free Personal
Team — Xcode refuses to sign it:

> `Provisioning profile "iOS Team Provisioning Profile" doesn't include the App
> Groups capability`

So the widgets share nothing at all. They compute prayer times themselves, from
their own location and their own configuration, using the vendored Swift port of
the same Adhan library the Dart side uses — so the app and the widgets cannot
drift apart. The one thing that genuinely cannot cross is the streak: it lives
in Firestore behind your login. It appears on the Lock Screen via the Live
Activity instead, where `Activity` passes state straight from the app.

## W1. Add the widget extension target

**File → New → Target… → Widget Extension**

| Field | Value |
|---|---|
| Product Name | `NoorWidgets` |
| Bundle Identifier | `<your app id>.NoorWidgets` |
| Include Live Activity | **✅ tick this** |
| Include Configuration App Intent | **✅ tick this** |
| Embed in | Runner |

Say yes when Xcode offers to activate the new scheme.

## W2. Replace the generated files

Delete every Swift file Xcode generated in the `NoorWidgets` group, then drag in
everything from `platform/ios/NoorWidgets/` — the twelve Noor files **and the
`Adhan` folder** (19 files, MIT licensed, vendored from
github.com/batoulapps/adhan-swift).

When Xcode asks, choose **Create groups** and tick **NoorWidgets** only.

## W3. Target membership

Only one file is shared with the app:

- [x] `PrayerActivityAttributes.swift` → tick **Runner as well as NoorWidgets**

Everything else belongs to NoorWidgets alone. `NoorWidgetBundle.swift` carries
`@main`; adding it to Runner gives you a duplicate-symbol link error.

Then drag `platform/ios/Runner/WidgetBridge.swift` into the **Runner** group
(Runner target only).

## W4. Let the widget see your location

Open the `NoorWidgets` **Info.plist** and add:

| Key | Type | Value |
|---|---|---|
| `NSWidgetWantsLocation` | Boolean | `YES` |

This reuses the permission the app already holds — the user is never asked
twice. Without it the widgets fall back to Makkah.

## W5. Turn it on

**Runner target → Build Settings → Swift Compiler – Custom Flags → Active
Compilation Conditions** → add `NOOR_WIDGETS`.

Set the NoorWidgets deployment target to **iOS 17.0** (App Intent configuration).

## W6. Run

Build and run Runner once, then long-press the home screen → **+** → search
**Noor**.

| Widget | Size | Shows |
|---|---|---|
| Prayer Times | medium | dimmed map of your region, live countdown, the day's five prayers |
| Prayer Progress | medium | curved gauge from the last prayer to the next |
| Next Prayer | small | next prayer, countdown, tonight's Tahajjud |

Long-press any widget → **Edit Widget** to pick the calculation method and Asr
madhab. **Set these to match Prayer Settings inside the app**, or the two will
show times a few minutes apart — the widget has no way to read the app's choice.

The Live Activity appears by itself when a prayer window opens.

## Notes

**The map** is rendered by the widget with `MKMapSnapshotter` and cached in the
extension's own container — no entitlement needed. It is deliberately zoomed to
~6°: a widget sits on a home screen other people can see, so it shows a region,
never a street. If rendering fails the widget falls back to its night-sky
gradient and nobody sees an error.

**Countdowns** use SwiftUI's `Text(timerInterval:)`, which ticks without waking
the extension. Timeline entries are scheduled at prayer boundaries only.

## Troubleshooting

| Symptom | Cause |
|---|---|
| Widgets show Makkah | No location yet — check `NSWidgetWantsLocation` (W4) and that Noor has location permission. |
| Widget times differ from the app by a few minutes | The widget's Edit Widget settings do not match Prayer Settings. |
| `cannot find 'PrayerTimes' in scope` | The `Adhan` folder was not added to the NoorWidgets target (W2). |
| `cannot find 'PrayerActivityAttributes' in scope` | W3 — not ticked into Runner. |
| Two `@main` / duplicate symbol | `NoorWidgetBundle.swift` was added to Runner. Remove it there. |
| Live Activity never appears | Deployment target below iOS 16.2, `NSSupportsLiveActivities` missing, or Live Activities off in Settings → Noor. |

---

# ⚠️ Fixes that revert if you regenerate `ios/`

Three fixes live in files that `flutter create` and Xcode will happily
overwrite. All three were found the hard way, on a device, and none of them
fail loudly — they fail as *plausible wrong behaviour*.

## 1. Build-phase order — `Runner.xcodeproj`

**Embed Foundation Extensions must run BEFORE the script phases.**

Xcode puts it last by default, which produces:

> `error: Cycle inside Runner; building could produce unreliable results.`

Flutter's *Thin Binary* and the CocoaPods phases declare no output files, so
Xcode assumes they touch the whole app bundle. Embedding the extension after
them closes a loop through Info.plist processing.

Correct order for the Runner target:

```
[CP] Check Pods Manifest.lock
Run Script
Sources
Frameworks
Resources
Embed Foundation Extensions   ← must sit here
Embed Frameworks
Thin Binary
[CP] Embed Pods Frameworks
[CP] Copy Pods Resources
```

Drag it in Build Phases, or re-run the reorder script.

## 2. Permission macros — `ios/Podfile`

`permission_handler_apple` compiles **every permission out** by default:

```c
#ifndef PERMISSION_CAMERA
    #define PERMISSION_CAMERA 0
#endif
```

A disabled permission reports `restricted`, which is indistinguishable from a
user denial. The symptom is the app saying *"Camera access is blocked"* while
Settings → Noor has **no Camera row at all** — because iOS was never asked.

`post_install` must define:

```ruby
'PERMISSION_CAMERA=1',
'PERMISSION_LOCATION=1',
'PERMISSION_NOTIFICATIONS=1',
```

Only these three. Location and notifications keep working even without them,
because `geolocator` and `flutter_local_notifications` ask iOS directly — which
is exactly why camera was the only one broken, and why it survived until
someone pressed the button on a real phone.

## 3. `NSWidgetWantsLocation` — `ios/NoorWidgets/Info.plist`

Must be a real key in that plist. Setting it as
`INFOPLIST_KEY_NSWidgetWantsLocation` in build settings does nothing here —
`INFOPLIST_KEY_*` only applies when Xcode *generates* the plist, and this target
has a file. Without the key the widgets silently fall back to Makkah.

## Also worth knowing

`flutter config --no-enable-swift-package-manager` is set globally on the
development machine. Flutter 3.47 defaults to SwiftPM, which cannot resolve
paths containing spaces — and this project lives under `islamic app /`. Renaming
the folder to something space-free would let you drop that setting.
