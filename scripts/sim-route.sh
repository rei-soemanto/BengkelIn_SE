#!/usr/bin/env bash
#
# sim-route.sh
# BengkelIn_SE
#
# Drive a booted iOS Simulator's GPS along a route, ending AT a seeded
# bengkel so you can exercise the live order-tracking / location flow.
#
# Unlike a static GPX, this script GENERATES simulation/route.gpx by
# interpolating START -> END, so the route is editable via env vars and
# always lands on the workshop you want to test against.
#
#   Default route:  (-7.2820000,112.6285000)  ->  Bengkel Eugene
#                                                  (-7.2865722,112.6320953)
#   ~650 m NW approach. Override with START / END env vars (see below).
#
# Usage:
#   scripts/sim-route.sh gen               # (re)generate simulation/route.gpx only
#   scripts/sim-route.sh init              # set the simulator to the START point
#   scripts/sim-route.sh go                # generate (if needed) + replay START -> END
#   scripts/sim-route.sh go --speed=25     # replay slower (m/s, default 40)
#   scripts/sim-route.sh end               # jump straight to the bengkel (END point)
#   scripts/sim-route.sh clear             # stop the sim & clear the GPS override
#
# Target device: defaults to "iPhone 17 Pro", resolved on the NEWEST installed
# iOS runtime (BengkelIn_SE targets iOS 26.2; older runtimes give "requires a
# newer version of iOS"). This matches scripts/restart-all.sh so it stays
# unambiguous even with all three demo sims booted.
#   Override by name:  DEVICE="iPhone Air" scripts/sim-route.sh go
#   or by UDID:        DEVICE=AE9CC18C-...  scripts/sim-route.sh go
#   Override route:    START="-7.2820,112.6285" END="-7.2866,112.6321" ... go
#   Override density:  POINTS=60 scripts/sim-route.sh gen
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GPX="$HERE/simulation/route.gpx"

DEVICE="${DEVICE:-iPhone 17 Pro}"
START="${START:--7.2820000,112.6285000}"
END="${END:--7.2865722,112.6320953}"   # Bengkel Eugene (seeded, Verified)
POINTS="${POINTS:-40}"

cmd="${1:-go}"
shift || true
SPEED="40"
for arg in "$@"; do
  case "$arg" in
    --speed=*) SPEED="${arg#*=}" ;;
  esac
done

START_LAT="${START%%,*}"; START_LON="${START##*,}"
END_LAT="${END%%,*}";     END_LON="${END##*,}"

# Resolve DEVICE (name or UDID) to a UDID on the newest installed iOS runtime,
# so `simctl location` is unambiguous even when several runtimes share a name.
resolve_udid() {
  # Already a UDID? use as-is.
  if [[ "$DEVICE" =~ ^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$ ]]; then
    echo "$DEVICE"; return
  fi
  local newest
  newest=$(xcrun simctl list devices available \
    | grep -oE -- '-- iOS [0-9.]+ --' | sort -V | tail -1)
  if [[ -z "$newest" ]]; then
    echo "!! No iOS simulator runtime installed (Xcode > Settings > Components)." >&2
    exit 1
  fi
  local udid
  udid=$(xcrun simctl list devices available | awk -v hdr="$newest" -v name="$DEVICE" '
    /^-- /{cur=$0}
    cur==hdr && index($0, name" (") {
      if (match($0, /[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}/)) { print substr($0, RSTART, RLENGTH); exit }
    }')
  if [[ -z "$udid" ]]; then
    echo "!! Device '$DEVICE' not found on ${newest//-- /}. Boot it first (scripts/restart-all.sh)." >&2
    exit 1
  fi
  echo "$udid"
}

# Linearly interpolate START -> END into POINTS waypoints and write the GPX.
generate_gpx() {
  mkdir -p "$(dirname "$GPX")"
  /usr/bin/python3 - "$GPX" "$START_LAT" "$START_LON" "$END_LAT" "$END_LON" "$POINTS" <<'PY'
import sys
gpx, slat, slon, elat, elon, n = sys.argv[1:7]
slat, slon, elat, elon, n = float(slat), float(slon), float(elat), float(elon), int(n)
n = max(n, 2)
lines = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<gpx version="1.1" creator="BengkelIn_SE route sim"',
    '     xmlns="http://www.topografix.com/GPX/1/1">',
    f'  <!-- Route: ({slat},{slon}) -> ({elat},{elon}) ; {n} pts -->',
]
for i in range(n):
    t = i / (n - 1)
    lat = slat + (elat - slat) * t
    lon = slon + (elon - slon) * t
    secs = i * 2
    lines.append(f'  <wpt lat="{lat:.7f}" lon="{lon:.7f}">')
    lines.append(f'    <ele>{t*10:.2f}</ele>')
    lines.append(f'    <time>2026-01-01T00:{secs//60:02d}:{secs%60:02d}Z</time>')
    lines.append('  </wpt>')
lines.append('</gpx>')
open(gpx, 'w').write('\n'.join(lines) + '\n')
print(f"Wrote {n} waypoints -> {gpx}")
PY
}

# Pull "lat,lon" waypoints out of the GPX for simctl.
waypoints() {
  /usr/bin/python3 - "$GPX" <<'PY'
import re, sys
txt = open(sys.argv[1]).read()
for lat, lon in re.findall(r'lat="([-0-9.]+)"\s+lon="([-0-9.]+)"', txt):
    print(f"{lat},{lon}")
PY
}

case "$cmd" in
  gen)
    generate_gpx
    ;;
  init)
    udid="$(resolve_udid)"
    echo "Setting START location on '$DEVICE' ($udid) -> $START_LAT,$START_LON"
    xcrun simctl location "$udid" set "$START_LAT,$START_LON"
    ;;
  end)
    udid="$(resolve_udid)"
    echo "Jumping to END (bengkel) on '$DEVICE' ($udid) -> $END_LAT,$END_LON"
    xcrun simctl location "$udid" set "$END_LAT,$END_LON"
    ;;
  go)
    [[ -f "$GPX" ]] || generate_gpx
    udid="$(resolve_udid)"
    echo "Replaying route on '$DEVICE' ($udid) at ${SPEED} m/s ..."
    # Waypoints have negative latitudes (leading '-') which simctl would read
    # as flags, so feed them via stdin ('-' = read waypoints from stdin).
    waypoints | xcrun simctl location "$udid" start --speed="$SPEED" -
    echo "Route playback started. Run '$0 clear' to stop."
    ;;
  clear)
    udid="$(resolve_udid)"
    echo "Clearing location override on '$DEVICE' ($udid)"
    xcrun simctl location "$udid" clear
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    echo "Usage: $0 {gen|init|go [--speed=N]|end|clear}" >&2
    exit 1
    ;;
esac
