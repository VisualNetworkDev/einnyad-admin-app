#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGING="$PROJECT_ROOT/build/ios/ipa-staging"
VERSION="${1:-1.0.0}"

cd "$PROJECT_ROOT"
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build ios --release --no-codesign

rm -rf "$STAGING"
mkdir -p "$STAGING/Payload"
cp -R "$PROJECT_ROOT/build/ios/iphoneos/Runner.app" "$STAGING/Payload/"
cd "$STAGING"
zip -qry "$PROJECT_ROOT/build/ios/EinnyadNails-Admin-$VERSION.ipa" Payload
shasum -a 256 "$PROJECT_ROOT/build/ios/EinnyadNails-Admin-$VERSION.ipa"
