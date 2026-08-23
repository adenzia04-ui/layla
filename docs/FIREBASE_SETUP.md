# Firebase setup

## 0. Prerequisites (none of these are installed on this Mac yet)

```bash
# Flutter
brew install --cask flutter

# Firebase CLI + FlutterFire
npm install -g firebase-tools
dart pub global activate flutterfire_cli
```

Then verify: `flutter doctor -v`

## 1. Create the project

1. https://console.firebase.google.com → **Add project** → name it `noor-app`.
2. Enable **Authentication → Sign-in method → Email/Password** *and* **Anonymous** (anonymous powers "Continue as guest").
3. Create **Firestore Database** in production mode, pick the region closest to your users.
4. Enable **Storage**.
5. Blaze plan is required only for Cloud Functions.

## 2. Wire it into the app

From the `noor/` directory:

```bash
flutterfire configure --project=noor-app --platforms=android,ios
```

This writes `lib/firebase_options.dart`, `android/app/google-services.json`, and `ios/Runner/GoogleService-Info.plist`. The placeholder `firebase_options.dart` in this repo throws a clear error until you run it.

## 3. Deploy rules, indexes and functions

```bash
firebase login
firebase use --add          # select noor-app
firebase deploy --only firestore:rules,firestore:indexes,storage
cd firebase/functions && npm install && cd ../..
firebase deploy --only functions
```

## 4. App Check (recommended before launch)

Console → App Check → register Play Integrity (Android) and DeviceCheck/App Attest (iOS), then uncomment the `FirebaseAppCheck.instance.activate(...)` block in `lib/main.dart`.

## 5. Composite indexes

`firebase/firestore.indexes.json` already declares:
- `stories`: `status ASC, createdAt DESC` — the feed query
- `tahajjud_presence`: `active ASC, expiresAt ASC` — live map + cleanup
