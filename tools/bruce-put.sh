#!/usr/bin/env bash
# bruce-put.sh — upload a local file to Bruce's storage over the serial CLI.
# Uses Bruce's `storage write -filepath <path> -size <N>` protocol (send N bytes).
#
# Usage:  ./bruce-put.sh <local-file> <device-path>
#   ./bruce-put.sh hello.js /scripts/hello.js
#
# Env: PORT (default /dev/ttyACM0)

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"   # tools/
ROOT="$(dirname "$HERE")"               # repo root (holds venv/)
PORT="${PORT:-/dev/ttyACM0}"
SRC="${1:-}"; DST="${2:-}"
if [ -z "$SRC" ] || [ -z "$DST" ]; then
    echo "usage: $0 <local-file> <device-path>" >&2; exit 2
fi
[ -f "$SRC" ] || { echo "no such file: $SRC" >&2; exit 1; }

[ -x "$HERE/free-port.sh" ] && "$HERE/free-port.sh" >/dev/null 2>&1
PY="$ROOT/venv/bin/python"; [ -x "$PY" ] || PY=python3

"$PY" - "$PORT" "$SRC" "$DST" <<'PY'
import sys, time
import serial
port, src, dst = sys.argv[1], sys.argv[2], sys.argv[3]

# Bruce reads line-by-line, re-appending '\n', until a line == "EOF" (or 5s idle).
# Normalize to '\n' endings (it strips '\n' but keeps stray '\r'), ensure trailing NL.
text = open(src, "r", newline="").read().replace("\r\n", "\n").replace("\r", "\n")
if not text.endswith("\n"):
    text += "\n"
payload = text.encode()
# -size is the buffer cap incl. the per-line '\n' Bruce re-adds; pad generously.
size = len(payload) + 64

s = serial.Serial(port, 115200, timeout=0.3)
time.sleep(0.3); s.reset_input_buffer()
s.write(f"storage write -filepath {dst} -size {size}\r\n".encode()); s.flush()
time.sleep(0.5)                 # wait for the "Reading input..." prompt
s.write(payload); s.flush()     # send the file content
time.sleep(0.2)
s.write(b"EOF\n"); s.flush()    # terminate the read

end = time.time() + 2.0
buf = b""
while time.time() < end:
    c = s.read(4096)
    if c: buf += c; end = time.time() + 0.4
s.close()
print(f"uploaded {len(payload)} content bytes -> {dst}")
print(buf.decode("utf-8", "replace").strip())
PY
