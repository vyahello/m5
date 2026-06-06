#!/usr/bin/env bash
# bruce-get.sh — download a file FROM the device to this machine (the reverse of
# bruce-put.sh). Uses Bruce's Web UI `/file?action=download` endpoint, which
# streams the file as binary (application/octet-stream) — so it works for pcap
# captures, RFID dumps, images, etc. that serial `storage read` would corrupt.
#
# Usage:
#   ./bruce-get.sh /BrucePCAP/handshakes/HS_xxx.pcap            # -> ./HS_xxx.pcap
#   ./bruce-get.sh /BrucePCAP/handshakes/HS_xxx.pcap ./loot/    # -> ./loot/HS_xxx.pcap
#   ./bruce-get.sh /tp-link_creds.csv creds.csv                # explicit filename
#   IP=192.168.1.111 ./bruce-get.sh /file.bin                  # skip serial IP probe
#
# Env:
#   IP        device IP (default: auto-detected over serial via `info`)
#   WEBUSER   Web UI user     (default: admin)
#   WEBPASS   Web UI password (default: bruce)
#   FS        filesystem      (default: LittleFS; use SD if a card is mounted)
#   PORT      serial port     (default: /dev/ttyACM0; only used for auto-IP/webui)
#   NOSTART   set to 1 to NOT auto-start the Web UI over serial
#
# Requires the device to be connected to the same network as this machine
# (2.4 GHz). The Web UI must be reachable; this script starts it for you unless
# NOSTART=1. Needs `curl`.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"   # tools/

REMOTE="${1:-}"
DEST="${2:-}"
if [ -z "$REMOTE" ]; then
    echo "usage: $0 <device-path> [local-dest]   e.g.  $0 /BrucePCAP/handshakes/HS_x.pcap ./loot/" >&2
    exit 2
fi
case "$REMOTE" in /*) ;; *) REMOTE="/$REMOTE" ;; esac   # ensure leading slash

command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }

WEBUSER="${WEBUSER:-admin}"
WEBPASS="${WEBPASS:-bruce}"
FS="${FS:-LittleFS}"
PORT="${PORT:-/dev/ttyACM0}"

# Resolve local destination: dir -> append basename; empty -> basename in CWD.
base="$(basename "$REMOTE")"
if [ -z "$DEST" ]; then
    DEST="$base"
elif [ -d "$DEST" ]; then
    DEST="${DEST%/}/$base"
fi

# --- Find the device IP (unless given) ----------------------------------------
if [ -z "${IP:-}" ]; then
    echo "Probing device IP over serial..." >&2
    info="$("$HERE/bruce-cmd.sh" info 2>/dev/null || true)"
    IP="$(printf '%s\n' "$info" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
          | grep -vE '^(0\.0\.0\.0|255\.|127\.)' | head -1)"
    if [ -z "$IP" ]; then
        echo "ERROR: could not detect an IP — is the device connected to Wi-Fi?" >&2
        echo "  Connect it (WiFi -> Connect, or: ./tools/bruce-cmd.sh \"wifi on\")" >&2
        echo "  then retry, or pass it explicitly:  IP=192.168.x.x $0 $REMOTE" >&2
        exit 1
    fi
    echo "Device IP: $IP" >&2
fi

# --- Make sure the Web UI is up ------------------------------------------------
if ! curl -fsS --max-time 3 "http://$IP/" -o /dev/null 2>/dev/null; then
    if [ "${NOSTART:-0}" = "1" ]; then
        echo "ERROR: Web UI not reachable at http://$IP/ (NOSTART=1 set)." >&2
        exit 1
    fi
    echo "Web UI not up — starting it over serial..." >&2
    "$HERE/bruce-cmd.sh" webui >/dev/null 2>&1 || true
    for i in 1 2 3 4 5 6 7 8; do
        sleep 1
        curl -fsS --max-time 3 "http://$IP/" -o /dev/null 2>/dev/null && break
    done
fi

# --- Authenticate (session cookie) then download -------------------------------
COOKIE="$(mktemp)"; trap 'rm -f "$COOKIE"' EXIT
curl -fsS -c "$COOKIE" \
     --data-urlencode "username=$WEBUSER" \
     --data-urlencode "password=$WEBPASS" \
     "http://$IP/login" -o /dev/null 2>/dev/null \
  || { echo "ERROR: login failed (check WEBUSER/WEBPASS; defaults admin/bruce)" >&2; exit 1; }

tmp="$(mktemp)"
if curl -fsS -b "$COOKIE" -G "http://$IP/file" \
        --data-urlencode "action=download" \
        --data-urlencode "fs=$FS" \
        --data-urlencode "name=$REMOTE" \
        -o "$tmp" 2>/dev/null; then
    mv "$tmp" "$DEST"
    size=$(wc -c < "$DEST" | tr -d ' ')
    echo "Downloaded: $REMOTE -> $DEST ($size bytes)"
    command -v file >/dev/null && echo "  type: $(file -b "$DEST")"
else
    rm -f "$tmp"
    echo "ERROR: download failed — file may not exist on $FS, or the path is wrong." >&2
    echo "  Check with: ./tools/bruce-cmd.sh \"ls $(dirname "$REMOTE")\"" >&2
    exit 1
fi
