#!/usr/bin/env bash
# bruce-rm.sh — delete one or more files from Bruce's storage over the serial CLI.
# Wraps Bruce's `storage remove -filepath <path>` command.
#
# Usage:
#   ./bruce-rm.sh /scripts/hello.js
#   ./bruce-rm.sh /scripts/pingpong.js /scripts/dino_game.js     # multiple
#   PORT=/dev/ttyACM0 ./bruce-rm.sh /scripts/demo.js
#
# Notes:
#   - Paths are absolute from the filesystem root (e.g. /scripts/foo.js).
#   - Deletes only the copy ON THE DEVICE; local files here are untouched.
#   - Frees the serial port first (only one owner allowed). Uses venv pyserial.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"   # tools/
ROOT="$(dirname "$HERE")"               # repo root (holds venv/)
PORT="${PORT:-/dev/ttyACM0}"

if [ "$#" -eq 0 ]; then
    echo "usage: $0 <device-path> [more-paths...]   e.g.  $0 /scripts/hello.js" >&2
    exit 2
fi

[ -x "$HERE/free-port.sh" ] && "$HERE/free-port.sh" >/dev/null 2>&1
PY="$ROOT/venv/bin/python"; [ -x "$PY" ] || PY=python3

"$PY" - "$PORT" "$@" <<'PY'
import sys, time
import serial
port = sys.argv[1]
paths = sys.argv[2:]
s = serial.Serial(port, 115200, timeout=0.3)
time.sleep(0.3); s.reset_input_buffer()

def send(cmd, wait=1.5):
    s.reset_input_buffer()
    s.write((cmd + "\r\n").encode()); s.flush()
    end = time.time() + wait; buf = b""
    while time.time() < end:
        c = s.read(4096)
        if c: buf += c; end = time.time() + 0.3
    return buf.decode("utf-8", "replace")

for p in paths:
    out = send(f"storage remove -filepath {p}")
    low = out.lower()
    if "removed" in low:
        print(f"  [OK]   deleted {p}")
    elif "not" in low and ("exist" in low or "found" in low):
        print(f"  [SKIP] not found: {p}")
    else:
        print(f"  [?]    {p}: {' '.join(out.split())[:120]}")
s.close()
PY