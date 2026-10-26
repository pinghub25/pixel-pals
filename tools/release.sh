#!/bin/zsh
# Archives Pixel Pals and uploads it to App Store Connect (it then shows up in TestFlight).
#
# Usage: tools/release.sh <TEAM_ID> <BUNDLE_ID>
#   e.g. tools/release.sh ABCDE12345 com.yourname.pixelpals
#
# Needs: a paid Apple Developer Program team signed in to Xcode, and an app record in
# App Store Connect with the same bundle ID.
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID=${1:?Team ID required}
BUNDLE_ID=${2:?Bundle ID required}
ARCHIVE=build/PixelPals.xcarchive

xcodegen generate -q

xcodebuild archive \
  -project IslandHub.xcodeproj \
  -scheme IslandHub \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  APP_BUNDLE_ID="$BUNDLE_ID"

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist tools/ExportOptions.plist \
  -exportPath build/export \
  -allowProvisioningUpdates

echo "Uploaded. It appears in App Store Connect → TestFlight after processing (usually 5–30 minutes)."
