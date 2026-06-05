#!/usr/bin/env bash
# free-port.sh — release the M5 serial port so esptool can use it.
#
# The #1 gotcha on this device: only one program can hold /dev/ttyACM0 at a time.
# A detached `screen` session (Ctrl-A D) keeps holding it, so esptool then fails
# with "Device or resource busy". This script kills any screen session and any
# other process holding the port, then confirms it's free.
#
# Usage:  ./free-port.sh [PORT]      (PORT defaults to /dev/ttyACM0)

# Note: no `set -e` here — screen/fuser legitimately return non-zero when there
# are no sessions / nobody holds the port, and that's success for us, not failure.
set -uo pipefail

PORT="${1:-/dev/ttyACM0}"

echo ">> Freeing $PORT ..."

# 1. Quit any screen sessions (they're the usual culprit) and clean dead sockets.
if command -v screen >/dev/null 2>&1; then
    for sess in $(screen -ls 2>/dev/null | grep -oE '[0-9]+\.[^[:space:]]+' || true); do
        echo "   killing screen session: $sess"
        screen -S "$sess" -X quit 2>/dev/null || true
    done
    screen -wipe >/dev/null 2>&1 || true
fi

# 2. Kill anything still holding the port (minicom, miniterm, a second screen...).
if command -v fuser >/dev/null 2>&1; then
    if fuser "$PORT" >/dev/null 2>&1; then
        echo "   killing remaining holders of $PORT"
        fuser -k "$PORT" 2>/dev/null || true
    fi
fi

sleep 1

# 3. Report final state.
if [ ! -e "$PORT" ]; then
    echo "!! $PORT does not exist — is the device plugged in? (check: ls /dev/ttyACM*)"
    exit 1
fi

if command -v fuser >/dev/null 2>&1 && fuser "$PORT" >/dev/null 2>&1; then
    echo "!! $PORT is STILL busy. Held by:"
    fuser -v "$PORT" 2>&1 || true
    exit 1
fi

echo ">> $PORT is free. You can now run esptool / flash / monitor."
