#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Al-Adhan.xcodeproj"
SCHEME="${SCHEME:-iPhone}"
CONFIGURATION="${CONFIGURATION:-Debug}"
DEVICE_ID="${DEVICE_ID:-00008150-000131A00A44401C}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$ROOT_DIR/build/DerivedData-device}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphoneos/iPhone.app"
BUNDLE_ID="${BUNDLE_ID:-app.riskcreatives.waktu}"
LOGIN_KEYCHAIN="${LOGIN_KEYCHAIN:-$HOME/Library/Keychains/login.keychain-db}"
KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-}"

echo "Deploying $SCHEME to device $DEVICE_ID"
echo "Project: $PROJECT_PATH"
echo "DerivedData: $DERIVED_DATA_PATH"

# SSH shells often lack the interactive keychain prompt codesign relies on.
# If a keychain password is provided, unlock the login keychain and refresh
# the partition list so codesign can use the signing key non-interactively.
if [[ -n "$KEYCHAIN_PASSWORD" ]]; then
  echo "Unlocking login keychain for codesign"
  security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$LOGIN_KEYCHAIN"
  security set-keychain-settings -lut 21600 "$LOGIN_KEYCHAIN"
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$LOGIN_KEYCHAIN"
fi

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

echo "Installing $APP_PATH"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

echo "Launching $BUNDLE_ID"
xcrun devicectl device process launch --device "$DEVICE_ID" --terminate-existing "$BUNDLE_ID"
