#!/usr/bin/env bash
# melody.sh — play a melody on the M5StickC Plus2 buzzer via Bruce's `tone` command.
# (The Plus2 has only a passive buzzer — `say`/`music_player` need a real speaker
#  and are not available. `tone` is the way to make sound.)
#
# Usage:
#   ./melody.sh                 # play the built-in demo tune (Twinkle Twinkle)
#   ./melody.sh mario           # play the Super Mario Bros theme
#   ./melody.sh zelda           # play the Zelda "secret found" jingle
#   ./melody.sh scale           # play a C-major scale
#   ./melody.sh "C4:300 E4:300 G4:300 C5:500"   # custom: note:ms space-separated
#
# Env: PORT (default /dev/ttyACM0)

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"   # tools/
ROOT="$(dirname "$HERE")"               # repo root (holds venv/)
PORT="${PORT:-/dev/ttyACM0}"

TWINKLE="C4:350 C4:350 G4:350 G4:350 A4:350 A4:350 G4:700 F4:350 F4:350 E4:350 E4:350 D4:350 D4:350 C4:700"
SCALE="C4:250 D4:250 E4:250 F4:250 G4:250 A4:250 B4:250 C5:400"
# Super Mario Bros. overworld theme (opening phrases)
MARIO="E5:120 E5:120 REST:120 E5:120 REST:120 C5:120 E5:120 REST:120 G5:120 REST:360 G4:120 REST:360 \
C5:160 REST:240 G4:160 REST:240 E4:160 REST:240 A4:120 REST:120 B4:120 REST:120 AS4:120 A4:120 REST:120 \
G4:135 E5:135 G5:135 A5:120 REST:120 F5:120 G5:120 REST:120 E5:120 REST:120 C5:120 D5:120 B4:120 REST:240"
# The Legend of Zelda "secret found / puzzle solved" jingle
ZELDA="G5:150 FS5:150 DS5:150 A4:150 GS4:150 E5:150 GS5:150 C6:650"

case "${1:-}" in
    ""|twinkle) TUNE="$TWINKLE" ;;
    mario)      TUNE="$MARIO" ;;
    zelda)      TUNE="$ZELDA" ;;
    scale)      TUNE="$SCALE" ;;
    *)          TUNE="$1" ;;
esac

[ -x "$HERE/free-port.sh" ] && "$HERE/free-port.sh" >/dev/null 2>&1
PY="$ROOT/venv/bin/python"; [ -x "$PY" ] || PY=python3

"$PY" - "$PORT" "$TUNE" <<'PY'
import sys, time
import serial
port, tune = sys.argv[1], sys.argv[2]

FREQ = {  # note name -> Hz (octaves 3-5 of the chromatic scale)
 "C3":131,"D3":147,"E3":165,"F3":175,"G3":196,"A3":220,"B3":247,
 "C4":262,"CS4":277,"D4":294,"DS4":311,"E4":330,"F4":349,"FS4":370,
 "G4":392,"GS4":415,"A4":440,"AS4":466,"B4":494,
 "C5":523,"CS5":554,"D5":587,"DS5":622,"E5":659,"F5":698,"FS5":740,
 "G5":784,"GS5":831,"A5":880,"AS5":932,"B5":988,"C6":1047,"REST":0,
}

s = serial.Serial(port, 115200, timeout=0.2)
time.sleep(0.3); s.reset_input_buffer()
for tok in tune.split():
    if ":" not in tok:
        continue
    note, ms = tok.split(":")
    ms = int(ms)
    hz = FREQ.get(note.upper())
    if hz is None:           # allow raw frequencies too, e.g. 440:300
        try: hz = int(note)
        except ValueError: continue
    if hz > 0:
        s.write(("tone %d %d\r\n" % (hz, ms)).encode()); s.flush()
    time.sleep(ms/1000.0 + 0.03)   # let the note finish before the next
s.close()
print("melody done")
PY