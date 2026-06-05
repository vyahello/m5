#!/usr/bin/env bash
# bruce-shell.sh — interactive Bruce serial console (115200 8N1).
# Frees the serial port, then drops you into a live prompt where you type Bruce
# commands and see the replies. This is the interactive version of bruce-cmd.sh.
#
# Usage:
#   ./bruce-shell.sh
#   PORT=/dev/ttyACM0 BAUD=115200 ./bruce-shell.sh
#
# In the shell, type a command + Enter, e.g.:
#   info | free | uptime | tone 2000 300 | storage list /scripts | js /scripts/pingpong.js
#
# EXIT: press  Ctrl-]   (that releases the port for esptool / bruce-cmd.sh again)
#
# Gotchas:
#   - Only one program can own the port — exit this before running bruce-cmd.sh/esptool.
#   - A looping script/game on the device starves the serial CLI: if you get no
#     replies, press a button on the device to exit the running script.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"   # tools/
ROOT="$(dirname "$HERE")"               # repo root (holds venv/)

PORT="${PORT:-/dev/ttyACM0}"
BAUD="${BAUD:-115200}"

if [ ! -e "$PORT" ]; then
    echo "!! $PORT not found — is the device plugged in? (try: ls /dev/ttyACM*)" >&2
    exit 1
fi

# Release any screen/monitor holding the port.
[ -x "$HERE/free-port.sh" ] && "$HERE/free-port.sh" >/dev/null 2>&1

PY="$ROOT/venv/bin/python"; [ -x "$PY" ] || PY=python3

cat <<EOF
------------------------------------------------------------------
 Bruce serial shell  ->  $PORT @ $BAUD
 Type a command + Enter:  info | free | storage list /scripts | ...
 EXIT: Ctrl-]     (a looping game/script on the device blocks replies)
------------------------------------------------------------------
EOF

# miniterm: local echo so you see what you type; CRLF line endings for Bruce CLI.
exec "$PY" -m serial.tools.miniterm --echo --eol CRLF "$PORT" "$BAUD"
