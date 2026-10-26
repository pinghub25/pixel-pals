#!/bin/zsh
# Builds Pixel Zodiac with a free Apple ID and installs it on a connected iPhone.
# Free installs expire after 7 days; run this again to renew.
# A free team can't use App Groups, so the entitlements are dropped (the widget can't see your pet).
#
# Usage: tools/install-free.sh <TEAM_ID> <DEVICE_ID>
#   Device IDs: xcrun devicectl list devices
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID=${1:?Team ID required}
DEVICE_ID=${2:?Device ID required}

xcodegen generate -q
xcodebuild -project IslandHub.xcodeproj -scheme IslandHub -configuration Release \
  -destination "id=$DEVICE_ID" -derivedDataPath build-device \
  -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_ENTITLEMENTS= build

xcrun devicectl device install app --device "$DEVICE_ID" build-device/Build/Products/Release-iphoneos/IslandHub.app
xcrun devicectl device process launch --device "$DEVICE_ID" com.matsavin.pixelpals || \
  echo "Installed. If it won't open: Settings › General › VPN & Device Management › your Apple ID › Trust."
