#!/usr/bin/env bash
# portals-set-ap.sh — set (or clear) the rogue-AP SSID on Evil Portal templates
# and push them to the device.
#
# Bruce auto-names the Evil Portal AP from a magic comment that must be the FIRST
# line of the template:   <!-- AP="My_SSID" -->
# This script writes/updates that line on each local portals/*.html (idempotent —
# it replaces an existing AP line, never stacks them), or removes it entirely with
# --clear, then uploads to the device.
#
# Usage:
#   ./tools/portals-set-ap.sh <AP_NAME> [file ...]    # set/replace the AP line
#     ./tools/portals-set-ap.sh Test_AP               #   all portals/*.html
#     ./tools/portals-set-ap.sh Test_AP portals/google.html portals/asus.html
#
#   ./tools/portals-set-ap.sh --clear [file ...]      # remove the AP line (no baked
#     ./tools/portals-set-ap.sh --clear               #   name → Bruce uses its
#     ./tools/portals-set-ap.sh --clear portals/google.html   # default / asks on-device
#
# Env:
#   PORT     serial port            (default /dev/ttyACM0, via bruce-put.sh)
#   DESTDIR  device folder          (default /PortalTemplates)
#   PUSH=0   edit local files only, skip the upload to the device
#
# Notes:
#   - Edits the local repo copies in place, then pushes. Re-run to change/clear.
#   - In set mode the SSID must be <=32 chars and must not contain a double-quote.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"   # tools/
ROOT="$(dirname "$HERE")"               # repo root
DESTDIR="${DESTDIR:-/PortalTemplates}"
PUSH="${PUSH:-1}"

arg1="${1:-}"
if [ -z "$arg1" ]; then
    echo "usage: $0 <AP_NAME> [file ...]   |   $0 --clear [file ...]" >&2
    exit 2
fi
shift

# --- mode: clear (strip the AP line) vs set (write/replace it) ---------------
if [ "$arg1" = "--clear" ] || [ "$arg1" = "--none" ]; then
    MODE="clear"
else
    MODE="set"
    AP="$arg1"
    case "$AP" in
        *'"'*) echo "error: AP name must not contain a double-quote (\")" >&2; exit 2 ;;
    esac
    if [ "${#AP}" -gt 32 ]; then
        echo "error: AP name '$AP' is ${#AP} chars; 802.11 SSID max is 32" >&2
        exit 2
    fi
    APLINE="<!-- AP=\"$AP\" -->"
fi

# --- collect target files ---------------------------------------------------
if [ "$#" -gt 0 ]; then
    FILES=("$@")
else
    FILES=("$ROOT"/portals/*.html)
fi
[ -e "${FILES[0]}" ] || { echo "no .html templates found in portals/" >&2; exit 1; }

if [ "$MODE" = "clear" ]; then
    echo "Clearing Evil Portal AP line on ${#FILES[@]} template(s)"
else
    echo "Setting Evil Portal AP -> \"$AP\" on ${#FILES[@]} template(s)"
fi

# awk program: drop an AP comment when it's line 1 (used by both modes).
# shellcheck disable=SC2016  # $0 is awk's field ref, intentionally not shell-expanded
DROP_AP='NR==1 && $0 ~ /^<!-- AP="[^"]*" -->[[:space:]]*$/ {next} {print}'

rc=0
for f in "${FILES[@]}"; do
    if [ ! -f "$f" ]; then
        echo "  [SKIP] no such file: $f" >&2; rc=1; continue
    fi
    tmp="$(mktemp)"
    if [ "$MODE" = "clear" ]; then
        awk "$DROP_AP" "$f" > "$tmp"
        tag="[CLR]"
    else
        # Drop an existing AP comment if it's line 1, then prepend the new one.
        { printf '%s\n' "$APLINE"; awk "$DROP_AP" "$f"; } > "$tmp"
        tag="[SET]"
    fi
    mv "$tmp" "$f"
    echo "  $tag  $(basename "$f")"

    if [ "$PUSH" = "1" ]; then
        dst="$DESTDIR/$(basename "$f")"
        if "$HERE/bruce-put.sh" "$f" "$dst" >/dev/null 2>&1; then
            echo "  [PUSH] -> $dst"
        else
            echo "  [FAIL] upload of $(basename "$f") failed" >&2; rc=1
        fi
    fi
done

if [ "$PUSH" != "1" ]; then
    echo "Done (local only; PUSH=0). Upload later with bruce-put.sh or re-run without PUSH=0."
elif [ "$MODE" = "clear" ]; then
    echo "Done. No AP name baked in — Bruce uses its default and/or asks on-device:"
    echo "WiFi -> WiFi Atks -> Evil Portal -> Custom Html -> pick a template -> set the AP name."
else
    echo "Done. On device: WiFi -> WiFi Atks -> Evil Portal -> Custom Html -> pick a"
    echo "template; the AP comes up as \"$AP\" (override at the prompt if needed)."
fi
exit "$rc"
