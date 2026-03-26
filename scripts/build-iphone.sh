#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/Al-Adhan.xcodeproj"
SCHEME="iPhone"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/Waktu.xcarchive}"
DESTINATION="${DESTINATION:-generic/platform=iOS}"

echo "Building $SCHEME"
echo "Project: $PROJECT_PATH"
echo "Archive: $ARCHIVE_PATH"
echo "Destination: $DESTINATION"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -archivePath "$ARCHIVE_PATH" \
  archive
