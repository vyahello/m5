#!/usr/bin/env bash
# bruce-get.sh — download a file FROM the device to this machine (the reverse of
# bruce-put.sh). Two transports:
#
#   WEB  (default): Bruce's Web UI `/file?action=download` — streams raw bytes
#        (application/octet-stream), so it is BINARY-SAFE (pcaps, RFID dumps,
#        images). Needs the device on your LAN (2.4 GHz); auto-detects the IP and
#        starts the Web UI for you.
#
#   SERIAL (--serial / -s): uses the serial `storage read` command — NO Wi-Fi
#        needed. TEXT ONLY: Bruce reads the file into an Arduino String via
#        readString(), which truncates at the first NUL byte and isn't 8-bit
#        clean, so it CORRUPTS binary files. There is also a small size cap
#        (~a few KB; over it Bruce shows "File is too big"). Fine for creds CSVs,
#        configs, wardrive .txt, .ir/.sub. Known-binary extensions are refused
#        unless you pass --force.
#
#   FLASH (--flash / -f): BINARY-SAFE and NO Wi-Fi. Dumps the whole LittleFS
#        partition with esptool over USB, then extracts the file from the image
#        with littlefs-python. Byte-exact — the right way to pull pcaps/dumps
#        without putting the device on a network. The 3 MB dump is cached at
#        /tmp/bruce-littlefs.bin and reused for subsequent files (--redump to
#        re-read the flash). Needs `littlefs-python` in the venv.
#
# Usage:
#   ./bruce-get.sh /BrucePCAP/handshakes/HS_xxx.pcap ./loot/   # web (binary-safe)
#   ./bruce-get.sh --flash /BrucePCAP/handshakes/HS_x.pcap ./loot/   # USB, no Wi-Fi
#   ./bruce-get.sh --serial /tp-link_creds.csv ./loot/         # serial (text only)
#   ./bruce-get.sh -s --force /weird.bin out.bin               # force serial on binary
#   IP=192.168.1.111 ./bruce-get.sh /file.pcap                 # skip serial IP probe
#
# Env (WEB mode):   IP (auto over serial), WEBUSER=admin, WEBPASS=bruce,
#                   FS=LittleFS (or SD), NOSTART=1 to not auto-start the Web UI.
# Env (FLASH mode): FLASH_IMG (cache path), LFS_OFFSET=0x4f0000, LFS_SIZE=0x300000.
# Env (all modes):  PORT=/dev/ttyACM0

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"   # tools/

MODE="web"; FORCE=0; REDUMP=0
ARGS=()
for a in "$@"; do
    case "$a" in
        -s|--serial) MODE="serial" ;;
        -f|--flash)  MODE="flash" ;;
        --web)       MODE="web" ;;
        --force)     FORCE=1 ;;
        --redump)    REDUMP=1 ;;
        -h|--help)   sed -n '2,30p' "$0"; exit 0 ;;
        *)           ARGS+=("$a") ;;
    esac
done
set -- "${ARGS[@]:-}"

REMOTE="${1:-}"
DEST="${2:-}"
if [ -z "$REMOTE" ]; then
    echo "usage: $0 [--serial|--flash] <device-path> [local-dest]" >&2
    echo "       e.g. $0 --flash /BrucePCAP/handshakes/HS_x.pcap ./loot/" >&2
    exit 2
fi
case "$REMOTE" in /*) ;; *) REMOTE="/$REMOTE" ;; esac   # ensure leading slash

PORT="${PORT:-/dev/ttyACM0}"

# Resolve local destination: dir -> append basename; empty -> basename in CWD.
base="$(basename "$REMOTE")"
if [ -z "$DEST" ]; then
    DEST="$base"
elif [ -d "$DEST" ]; then
    DEST="${DEST%/}/$base"
fi

# ------------------------------------------------------------------ SERIAL mode
if [ "$MODE" = "serial" ]; then
    case "${base##*.}" in
        pcap|cap|pcapng|bin|png|jpg|jpeg|gif|bmp|nfc|rfid|sub|gz|zip|img)
            if [ "$FORCE" != "1" ]; then
                echo "REFUSING: '$base' looks binary — serial 'storage read' truncates" >&2
                echo "binary at the first NUL byte and corrupts it. Use web mode (drop" >&2
                echo "--serial) for a binary-safe download, or pass --force to override." >&2
                exit 1
            fi ;;
    esac
    PY="$(dirname "$HERE")/venv/bin/python"; [ -x "$PY" ] || PY=python3
    [ -x "$HERE/free-port.sh" ] && "$HERE/free-port.sh" >/dev/null 2>&1
    "$PY" - "$PORT" "$REMOTE" "$DEST" <<'PY'
import sys, time
try:
    import serial
except ImportError:
    sys.exit("pyserial not found — source venv/bin/activate && pip install pyserial")
port, remote, dest = sys.argv[1], sys.argv[2], sys.argv[3]
s = serial.Serial(port, 115200, timeout=0.3)
time.sleep(0.3); s.reset_input_buffer()
s.write(("storage read " + remote + "\r\n").encode()); s.flush()
end = time.time() + 3.0; buf = b""
while time.time() < end:
    c = s.read(8192)
    if c: buf += c; end = time.time() + 0.5
s.close()
# Frame: "COMMAND: storage read <path>\r\n" + <content> + trailing "#" prompt.
text = buf.decode("latin-1")
lines = text.split("\n")
# drop the echoed command line(s)
while lines and lines[0].lstrip().startswith("COMMAND:"):
    lines.pop(0)
# drop a trailing prompt line ("#") and trailing blanks
while lines and lines[-1].strip() in ("#", ""):
    lines.pop()
content = "\n".join(lines)
content = content.replace("\r", "")
if not content.strip():
    sys.exit("ERROR: empty reply — file may be over the serial size cap "
             "(\"File is too big\") or not exist. Use web mode for big/binary files.")
with open(dest, "wb") as f:
    f.write(content.encode("latin-1"))
print("Downloaded (serial/text): %s -> %s (%d bytes)" % (remote, dest, len(content)))
PY
    exit $?
fi

# ------------------------------------------------------------------- FLASH mode
# Binary-safe, USB-only (no Wi-Fi): dump the LittleFS partition with esptool and
# extract the file from the image with littlefs-python. Byte-exact.
if [ "$MODE" = "flash" ]; then
    PY="$(dirname "$HERE")/venv/bin/python"; [ -x "$PY" ] || PY=python3
    "$PY" -c "import littlefs" 2>/dev/null \
      || { echo "littlefs-python missing — install: $PY -m pip install littlefs-python" >&2; exit 1; }

    IMG="${FLASH_IMG:-/tmp/bruce-littlefs.bin}"
    OFF="${LFS_OFFSET:-0x4f0000}"      # Bruce LittleFS partition offset
    SIZE="${LFS_SIZE:-0x300000}"       # ...and size (3 MB) — see docs/03

    if [ ! -f "$IMG" ] || [ "$REDUMP" = "1" ]; then
        echo "Dumping LittleFS ($OFF +$SIZE) over USB -> $IMG ..." >&2
        [ -x "$HERE/free-port.sh" ] && "$HERE/free-port.sh" >/dev/null 2>&1
        "$PY" -m esptool --port "$PORT" --baud 921600 read-flash "$OFF" "$SIZE" "$IMG" >/dev/null 2>&1 \
          || { echo "ERROR: esptool flash dump failed (port busy? close monitors)" >&2; exit 1; }
    else
        echo "Reusing cached image $IMG (pass --redump to re-read the flash)." >&2
    fi

    "$PY" - "$IMG" "$REMOTE" "$DEST" <<'PY'
import sys, os
from littlefs import LittleFS
img, remote, dest = sys.argv[1], sys.argv[2], sys.argv[3]
data = open(img, "rb").read()
fs = LittleFS(block_size=4096, block_count=len(data)//4096, mount=False)
fs.context.buffer = bytearray(data)
try:
    fs.mount()
except Exception as e:
    sys.exit("ERROR: could not mount LittleFS image: %s" % e)
try:
    with fs.open(remote, "rb") as f:
        blob = f.read()
except Exception as e:
    sys.exit("ERROR: '%s' not found in image (%s). List it with --help recipe in docs/06." % (remote, e))
d = os.path.dirname(dest)
if d:
    os.makedirs(d, exist_ok=True)
open(dest, "wb").write(blob)
print("Downloaded (flash/USB, binary-safe): %s -> %s (%d bytes)" % (remote, dest, len(blob)))
PY
    rc=$?
    command -v file >/dev/null && [ -f "$DEST" ] && echo "  type: $(file -b "$DEST")"
    exit $rc
fi

# --------------------------------------------------------------------- WEB mode
command -v curl >/dev/null || { echo "curl is required for web mode" >&2; exit 1; }
WEBUSER="${WEBUSER:-admin}"
WEBPASS="${WEBPASS:-bruce}"
FS="${FS:-LittleFS}"

# Find the device IP (unless given).
if [ -z "${IP:-}" ]; then
    echo "Probing device IP over serial..." >&2
    info="$("$HERE/bruce-cmd.sh" info 2>/dev/null || true)"
    IP="$(printf '%s\n' "$info" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' \
          | grep -vE '^(0\.0\.0\.0|255\.|127\.)' | head -1)"
    if [ -z "$IP" ]; then
        echo "ERROR: could not detect an IP — is the device connected to Wi-Fi?" >&2
        echo "  Connect it (WiFi -> Connect, or: ./tools/bruce-cmd.sh \"wifi on\")," >&2
        echo "  pass IP=192.168.x.x explicitly, or use --serial for small TEXT files." >&2
        exit 1
    fi
    echo "Device IP: $IP" >&2
fi

# Make sure the Web UI is up.
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

# Authenticate (session cookie) then download.
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
    echo "Downloaded (web): $REMOTE -> $DEST ($size bytes)"
    command -v file >/dev/null && echo "  type: $(file -b "$DEST")"
else
    rm -f "$tmp"
    echo "ERROR: download failed — file may not exist on $FS, or the path is wrong." >&2
    echo "  Check with: ./tools/bruce-cmd.sh \"ls $(dirname "$REMOTE")\"" >&2
    exit 1
fi
