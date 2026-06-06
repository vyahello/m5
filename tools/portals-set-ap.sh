#!/usr/bin/env bash
# portals-set-ap.sh — set the rogue-AP SSID on Evil Portal templates and push them.
#
# Bruce auto-names the Evil Portal AP from a magic comment that must be the FIRST
# line of the template:   <!-- AP="My_SSID" -->
# This script writes/updates that line on each local portals/*.html (idempotent —
# it replaces an existing AP line, never stacks them) then uploads to the device.
#
# Usage:
#   ./tools/portals-set-ap.sh <AP_NAME> [file ...]
#     ./tools/portals-set-ap.sh Test_AP                 # all portals/*.html
#     ./tools/portals-set-ap.sh Test_AP portals/google.html portals/asus.html
#
# Env:
#   PORT     serial port            (default /dev/ttyACM0, via bruce-put.sh)
#   DESTDIR  device folder          (default /PortalTemplates)
#   PUSH=0   edit local files only, skip the upload to the device
#
# Notes:
#   - Edits the local repo copies in place (so the SSID persists in the template),
#     then pushes. Re-run with a new name to change it everywhere.
#   - SSID must be <=32 chars and must not contain a double-quote.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"   # tools/
ROOT="$(dirname "$HERE")"               # repo root
DESTDIR="${DESTDIR:-/PortalTemplates}"
PUSH="${PUSH:-1}"

AP="${1:-}"
if [ -z "$AP" ]; then
    echo "usage: $0 <AP_NAME> [file ...]   e.g.  $0 Test_AP" >&2
    exit 2
fi
shift

# --- validate the SSID ------------------------------------------------------
case "$AP" in
    *'"'*) echo "error: AP name must not contain a double-quote (\")" >&2; exit 2 ;;
esac
if [ "${#AP}" -gt 32 ]; then
    echo "error: AP name '$AP' is ${#AP} chars; 802.11 SSID max is 32" >&2
    exit 2
fi

# --- collect target files ---------------------------------------------------
if [ "$#" -gt 0 ]; then
    FILES=("$@")
else
    FILES=("$ROOT"/portals/*.html)
fi
[ -e "${FILES[0]}" ] || { echo "no .html templates found in portals/" >&2; exit 1; }

APLINE="<!-- AP=\"$AP\" -->"
echo "Setting Evil Portal AP -> \"$AP\" on ${#FILES[@]} template(s)"

rc=0
for f in "${FILES[@]}"; do
    if [ ! -f "$f" ]; then
        echo "  [SKIP] no such file: $f" >&2; rc=1; continue
    fi
    tmp="$(mktemp)"
    # Drop an existing AP comment if it's already line 1, then prepend the new one.
    {
        printf '%s\n' "$APLINE"
        awk 'NR==1 && $0 ~ /^<!-- AP="[^"]*" -->[[:space:]]*$/ {next} {print}' "$f"
    } > "$tmp"
    mv "$tmp" "$f"
    echo "  [SET]  $(basename "$f")"

    if [ "$PUSH" = "1" ]; then
        dst="$DESTDIR/$(basename "$f")"
        if "$HERE/bruce-put.sh" "$f" "$dst" >/dev/null 2>&1; then
            echo "  [PUSH] -> $dst"
        else
            echo "  [FAIL] upload of $(basename "$f") failed" >&2; rc=1
        fi
    fi
done

if [ "$PUSH" = "1" ]; then
    echo "Done. On device: WiFi -> WiFi Atks -> Evil Portal -> Custom Html -> pick a"
    echo "template; the AP comes up as \"$AP\" (override at the prompt if needed)."
else
    echo "Done (local only; PUSH=0). Upload later with bruce-put.sh or re-run without PUSH=0."
fi
exit "$rc"
