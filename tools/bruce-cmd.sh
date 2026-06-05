#!/usr/bin/env bash
# bruce-cmd.sh — send a command to Bruce firmware over the serial CLI and print
# the reply. Bruce's serial interface runs at 115200 8N1 and accepts Flipper-Zero
# style commands (info, tone, ir, subghz, storage, settings, gpio, js, ...).
#
# Usage (commands VERIFIED on this M5StickC Plus2 / Bruce v1.15):
#   ./bruce-cmd.sh info                  # firmware / device / wifi
#   ./bruce-cmd.sh "tone 2000 300"       # buzzer beep (freq, ms)
#   ./bruce-cmd.sh free                  # heap + PSRAM
#   ./bruce-cmd.sh uptime
#   ./bruce-cmd.sh "storage list /scripts"
#   ./bruce-cmd.sh "js /scripts/watchface.js"
#   PORT=/dev/ttyACM0 WAIT=2.0 ./bruce-cmd.sh free
#
# Notes:
#   - `say` and `led` are NOT in this build (no speaker / no RGB LED) — they
#     return "ERROR: Command not found". Use `tone`/`beep`; set colors via Config.
#   - Build/hardware decides which commands exist; "Command not found" = not built in.
#   - Frees the port of any screen/monitor first (only one owner allowed).
#   - Uses the venv's pyserial (installed alongside esptool).

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"   # tools/
ROOT="$(dirname "$HERE")"               # repo root (holds venv/)

PORT="${PORT:-/dev/ttyACM0}"
WAIT="${WAIT:-1.5}"          # seconds to listen for the reply
CMD="$*"

if [ -z "$CMD" ]; then
    echo "usage: $0 <bruce command>   e.g.  $0 info" >&2
    exit 2
fi

# Make sure nothing else is holding the port (screen, etc.).
[ -x "$HERE/free-port.sh" ] && "$HERE/free-port.sh" >/dev/null 2>&1

PY="$ROOT/venv/bin/python"
[ -x "$PY" ] || PY=python3

"$PY" - "$PORT" "$WAIT" "$CMD" <<'PY'
import sys, time
try:
    import serial
except ImportError:
    sys.exit("pyserial not found — run: source venv/bin/activate && pip install pyserial")

port, wait, cmd = sys.argv[1], float(sys.argv[2]), sys.argv[3]
try:
    s = serial.Serial(port, 115200, timeout=0.2)
except Exception as e:
    sys.exit(f"could not open {port}: {e}")

time.sleep(0.3)
s.reset_input_buffer()
s.write((cmd + "\r\n").encode())
s.flush()

end = time.time() + wait
buf = b""
while time.time() < end:
    chunk = s.read(4096)
    if chunk:
        buf += chunk
        end = time.time() + 0.4   # extend a bit while data keeps coming
s.close()

out = buf.decode("utf-8", "replace").strip()
print(out if out else "(no reply — command may have run silently, or try a longer WAIT)")
PY
