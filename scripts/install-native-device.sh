#!/bin/bash
# Run by the development agent on the owner's authorized Mac workspace.
set -euo pipefail
if [[ "$(uname -s)" != Darwin ]]; then
  echo 'Native installation needs the authorized Mac workspace and Xcode.' >&2
  exit 1
fi
xcodebuild -version >/dev/null
EDIZ_PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EDIZ_DEVICE_BUILD="${TMPDIR:-/tmp}/ediz-device-build"
EDIZ_DEVICE_LIST="$(mktemp)"
trap 'rm -f "$EDIZ_DEVICE_LIST"' EXIT
if [[ -z "${EDIZ_TEAM_ID:-}" ]]; then
  EDIZ_TEAM_ID="$(security find-identity -v -p codesigning | python3 -c 'import re,sys; teams=sorted(set(re.findall(r"Apple Development:.*?\(([A-Z0-9]{10})\)",sys.stdin.read()))); print(teams[0] if len(teams)==1 else "")')"
fi
if [[ -z "$EDIZ_TEAM_ID" ]]; then
  echo 'Authorize the owner Apple ID in Xcode first. An existing development identity is needed; no password is stored by this script.' >&2
  exit 1
fi
xcrun devicectl list devices --json-output "$EDIZ_DEVICE_LIST" >/dev/null
if [[ -z "${EDIZ_DEVICE_ID:-}" ]]; then
  EDIZ_DEVICE_ID="$(python3 -c 'import json,sys; devices=json.load(open(sys.argv[1])).get("result",{}).get("devices",[]); phones=[d for d in devices if d.get("hardwareProperties",{}).get("deviceType")=="iPhone" and d.get("connectionProperties",{}).get("pairingState")=="paired"]; print(phones[0]["identifier"] if len(phones)==1 else "")' "$EDIZ_DEVICE_LIST")"
fi
if [[ -z "$EDIZ_DEVICE_ID" ]]; then
  echo 'Connect and trust the owner iPhone. With multiple phones connected, the agent must select the owner device explicitly.' >&2
  exit 1
fi
xcodebuild -project "$EDIZ_PROJECT_ROOT/ios/App/App.xcodeproj" -scheme App \
  -configuration Release -destination "id=$EDIZ_DEVICE_ID" \
  -derivedDataPath "$EDIZ_DEVICE_BUILD" -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration DEVELOPMENT_TEAM="$EDIZ_TEAM_ID" \
  CODE_SIGN_STYLE=Automatic build
xcrun devicectl device install app --device "$EDIZ_DEVICE_ID" "$EDIZ_DEVICE_BUILD/Build/Products/Release-iphoneos/App.app"
xcrun devicectl device process launch --device "$EDIZ_DEVICE_ID" com.ediz.os
