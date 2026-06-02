#!/usr/bin/env bash
#
# restart-all.sh
# Shut down all simulators, boot 3 devices, build BengkelIn_SE once,
# then install + (re)launch the app on all three — useful for testing
# multi-user flows (customer ↔ bengkel bidding) side by side.
#
# NOTE: BengkelIn_SE deploys to iOS 26.2, so devices are resolved on the
# NEWEST installed iOS runtime (older-runtime sims give "requires a newer
# version of iOS"). Install a matching iOS runtime in Xcode if the build
# won't launch.
#
set -euo pipefail

# --- Config ---------------------------------------------------------------
SCHEME="BengkelIn_SE"
BUNDLE_ID="com.madweek10.BengkelIn-SE"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$PROJECT_DIR/BengkelIn_SE.xcodeproj"
DERIVED="$PROJECT_DIR/build"

# Device names to boot — resolved on the newest iOS runtime (edit freely).
DEVICES=("iPhone 17 Pro" "iPhone 17e" "iPhone Air")
# -------------------------------------------------------------------------

echo "==> Shutting down all simulators"
xcrun simctl shutdown all 2>/dev/null || true

# Newest installed iOS runtime header, e.g. "-- iOS 26.4 --".
NEWEST_IOS=$(xcrun simctl list devices available \
  | grep -oE -- '-- iOS [0-9.]+ --' | sort -V | tail -1)
if [[ -z "$NEWEST_IOS" ]]; then
  echo "!! No iOS simulator runtime installed. Add one via Xcode > Settings > Components."
  exit 1
fi
echo "==> Targeting runtime: ${NEWEST_IOS//-- /}"

# Resolve each device name to a UDID *within the newest runtime* and boot it.
UDIDS=()
for name in "${DEVICES[@]}"; do
  udid=$(xcrun simctl list devices available | awk -v hdr="$NEWEST_IOS" -v name="$name" '
    /^-- /{cur=$0}
    cur==hdr && index($0, name" (") {
      if (match($0, /[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}/)) { print substr($0, RSTART, RLENGTH); exit }
    }')
  if [[ -z "$udid" ]]; then
    echo "!! Device not found on ${NEWEST_IOS//-- /}: $name (skipping)"
    continue
  fi
  echo "==> Booting $name ($udid)"
  xcrun simctl boot "$udid" 2>/dev/null || true
  UDIDS+=("$udid")
done

if [[ ${#UDIDS[@]} -eq 0 ]]; then
  echo "!! No matching devices booted. Edit DEVICES to names available on ${NEWEST_IOS//-- /}."
  exit 1
fi

echo "==> Opening Simulator app"
open -a Simulator

echo "==> Building $SCHEME (this can take a minute)"
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  -derivedDataPath "$DERIVED" \
  build | tail -5

APP_PATH="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "!! Build product not found at $APP_PATH"
  exit 1
fi

for udid in "${UDIDS[@]}"; do
  echo "==> Installing on $udid"
  xcrun simctl install "$udid" "$APP_PATH"
  echo "==> Launching on $udid"
  xcrun simctl launch "$udid" "$BUNDLE_ID" >/dev/null
done

echo "==> Done. $SCHEME running on ${#UDIDS[@]} simulator(s)."
