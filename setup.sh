#!/usr/bin/env bash
# Noor — one-time project setup.
# Generates the native android/ and ios/ folders, then applies Noor's overrides.
set -euo pipefail

ORG="com.noorapp"
cd "$(dirname "$0")"

command -v flutter >/dev/null 2>&1 || {
  echo "✗ Flutter not found. Install it first:  brew install --cask flutter"
  exit 1
}

echo "▸ Backing up the files 'flutter create' likes to overwrite…"
mkdir -p .setup-backup
cp pubspec.yaml analysis_options.yaml .setup-backup/
cp lib/main.dart .setup-backup/

echo "▸ Generating native platform folders…"
flutter create . --org "$ORG" --project-name noor --platforms=android,ios

echo "▸ Restoring Noor's own files…"
cp .setup-backup/pubspec.yaml .
cp .setup-backup/analysis_options.yaml .
cp .setup-backup/main.dart lib/main.dart
rm -rf .setup-backup

echo "▸ Applying platform overrides…"
cp platform/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
cp platform/Info.plist          ios/Runner/Info.plist
mkdir -p android/app/src/main/kotlin/com/noorapp/noor
cp platform/kotlin/*.kt         android/app/src/main/kotlin/com/noorapp/noor/

# iOS app-target sources. The two app extensions and the App Group have to be
# added in Xcode by hand — a shell script cannot edit an .xcodeproj safely.
# platform/ios/README.md is the checklist.
cp platform/ios/Runner/AppDelegate.swift        ios/Runner/AppDelegate.swift
# Staged, not compiled: both files are inert until you add them to the Runner
# target and set NOOR_SCREEN_TIME. Runner.entitlements is deliberately NOT
# copied — the family-controls key would break code signing with a personal
# Apple team, and Xcode writes it for you when you add the capability.
cp platform/ios/Runner/PrayerLockBridge.swift   ios/Runner/PrayerLockBridge.swift
cp platform/ios/Shared/NoorLockShared.swift     ios/Runner/NoorLockShared.swift

# firebase_auth needs API 23; image_picker and geolocator are happy there too.
GRADLE="android/app/build.gradle.kts"
[ -f "$GRADLE" ] || GRADLE="android/app/build.gradle"
if grep -q "minSdk" "$GRADLE"; then
  echo "▸ Raising minSdk to 23 (required by firebase_auth) in $GRADLE"
  sed -i '' -E 's/minSdk *=? *flutter\.minSdkVersion/minSdk = 23/' "$GRADLE" || true
  sed -i '' -E 's/minSdkVersion flutter\.minSdkVersion/minSdkVersion 23/' "$GRADLE" || true
fi

echo "▸ Fetching packages…"
flutter pub get || {
  echo "⚠ Version resolution failed — trying an upgrade pass…"
  flutter pub upgrade --major-versions
}

cat <<'EOF'

✓ Setup complete.

Next:
  1. flutterfire configure --project=<your-firebase-project> --platforms=android,ios
  2. firebase deploy --only firestore:rules,firestore:indexes,storage
  3. flutter run

Verify first with:  flutter analyze && flutter test

Read docs/FIREBASE_SETUP.md for the full walkthrough, and
docs/PRAYER_LOCK_LIMITATIONS.md before touching the prayer lock.

iOS app-pausing (Screen Time) needs manual Xcode setup and an Apple
entitlement — follow platform/ios/README.md. Until then the app builds and
runs normally with the lock reported as unavailable.
EOF
