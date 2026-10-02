#!/usr/bin/env bash
# rfid125.sh — verify + bring-up a 125 kHz RFID reader (RDM6300 / HW-205) on the
# M5StickC Plus2 running Bruce v1.15, over USB serial — WITHOUT flashing anything.
#
# What it does (all over the serial CLI @ 115200, no Wi-Fi):
#   1. Frees the port + confirms the device/firmware is alive (`info`).
#   2. WIRING SELF-TEST — forces the ESP32 internal pulldown on the RFID RX pin
#      (G33 by default) and TX pin (G32) and reads them. The RDM6300 TX idles HIGH
#      (~3.44 V through your 1k/2.2k divider, ~688 ohm source), which OVERPOWERS the
#      ~45k internal pulldown, so:
#         RX pin reads 1  -> reader powered + data line correctly on this pin   PASS
#         RX pin reads 0  -> nothing driving it (wrong pin / not powered)       FAIL
#         TX pin reads 1  -> your data wire is on the TX pin by mistake         WARN
#   3. LIVE READ TEST — samples the RX pin while you hold a fob on the coil. At idle
#      the line is a steady 1; while the RDM6300 streams a tag the start/data bits
#      pull it LOW, so zeros appearing = real tag data flowing on the right pin.
#
# It does NOT decode the UID: that needs Bruce's own UART decoder. For the actual
# read, use the device UI:  Main menu -> RFID -> Read 125kHz  -> tap fob ->
# Select -> Save file  (then pull it with tools/bruce-get.sh).
#
# Why these pins: Bruce's RFID125 reads uart_bus.rx/.tx; on the cplus2 those fall
# back to SERIAL_RX=GROVE_SCL=33 and SERIAL_TX=GROVE_SDA=32 (see docs/06-pentesting
# section 10.1). RDM6300 TX -> G33 (blue). G32 (yellow) is unused.
#
# Usage:
#   ./tools/rfid125.sh                 # info + self-test + 15s live read test
#   ./tools/rfid125.sh selftest        # info + self-test only (no fob needed)
#   ./tools/rfid125.sh 25              # live test window = 25 seconds
#   PORT=/dev/ttyACM0 RXPIN=33 TXPIN=32 ./tools/rfid125.sh
#
# Env: PORT (default /dev/ttyACM0), RXPIN (33), TXPIN (32), SECS (live seconds, 15).

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"   # tools/
ROOT="$(dirname "$HERE")"               # repo root (holds venv/)

PORT="${PORT:-/dev/ttyACM0}"
RXPIN="${RXPIN:-33}"                     # Bruce RFID125 RX = uart_bus.rx = G33 (blue)
TXPIN="${TXPIN:-32}"                     # Bruce RFID125 TX = uart_bus.tx = G32 (yellow)
SECS="${SECS:-15}"
MODE="all"

# arg: "selftest" or a number of seconds for the live window
case "${1:-}" in
    selftest|self|st) MODE="selftest" ;;
    ''              ) : ;;
    *[!0-9]*        ) echo "usage: $0 [selftest | <seconds>]" >&2; exit 2 ;;
    *               ) SECS="$1" ;;
esac

# Free the port of any screen/monitor (only one owner allowed).
[ -x "$HERE/free-port.sh" ] && "$HERE/free-port.sh" >/dev/null 2>&1

# Pick a python that can actually import pyserial (the repo venv currently can't).
PY=""
for c in "$ROOT/venv/bin/python" python3 python; do
    if [ -x "$c" ] || command -v "$c" >/dev/null 2>&1; then
        if "$c" -c "import serial" >/dev/null 2>&1; then PY="$c"; break; fi
    fi
done
[ -n "$PY" ] || { echo "No python with pyserial found. Try: pip install pyserial" >&2; exit 1; }

"$PY" - "$PORT" "$RXPIN" "$TXPIN" "$SECS" "$MODE" <<'PY'
import sys, time, re
import serial

port, rxpin, txpin, secs, mode = (
    sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), float(sys.argv[4]), sys.argv[5]
)

# Open once, DTR/RTS held low so we don't toggle the auto-reset line mid-run.
s = serial.Serial()
s.port = port; s.baudrate = 115200; s.timeout = 0.05
s.dtr = False; s.rts = False
try:
    s.open()
except Exception as e:
    sys.exit("could not open %s: %s" % (port, e))
time.sleep(2.0)            # settle (absorbs a boot if the open reset the MCU)
s.reset_input_buffer()

def cmd(c, wait=0.35):
    s.reset_input_buffer()
    s.write((c + "\r\n").encode()); s.flush()
    time.sleep(wait)
    out = s.read(8192).decode("utf-8", "replace")
    return [l.strip() for l in out.splitlines() if l.strip() and l.strip() != c]

def read_pin(pin, n=6):
    vals = []
    for _ in range(n):
        r = cmd("gpio read %d" % pin, 0.18)
        vals.append(next((x for x in r if x in ("0", "1")), "?"))
    return vals

# ---- 1. device alive -------------------------------------------------------
print("== Device ==")
info = cmd("info", 1.2)
if not info:
    sys.exit("No reply on %s — is the stick connected and is the port free?" % port)
for l in info[:3]:
    print("   " + l)

# ---- 2. wiring self-test ---------------------------------------------------
print("\n== Wiring self-test (internal pulldown; RDM6300 idles HIGH) ==")
cmd("gpio mode %d 9" % rxpin); cmd("gpio mode %d 9" % txpin)  # 9 = INPUT_PULLDOWN
time.sleep(0.2)
rx = read_pin(rxpin); tx = read_pin(txpin)
cmd("gpio mode %d 1" % rxpin); cmd("gpio mode %d 1" % txpin)  # back to plain INPUT

rx_hi = rx.count("1"); tx_hi = tx.count("1")
print("   RX G%-2d (expect 1): %s" % (rxpin, " ".join(rx)))
print("   TX G%-2d (expect 0): %s" % (txpin, " ".join(tx)))

ok = True
if rx_hi == len(rx):
    print("   -> PASS: RFID data line is driven HIGH on G%d (reader powered, right pin)." % rxpin)
elif rx_hi == 0:
    ok = False
    print("   -> FAIL: G%d reads LOW. Reader not powered (LED off? check 5V/GND) or" % rxpin)
    print("            the data wire is NOT on G%d. It must go: RDM6300 TX -> 1k -> G%d." % (rxpin, rxpin))
else:
    print("   -> ODD: G%d is unstable (%s). Loose divider/ground? Reseat the junction." % (rxpin, " ".join(rx)))
if tx_hi:
    ok = False
    print("   -> WARN: G%d (TX) is also driven HIGH — your data wire may be on G%d by" % (txpin, txpin))
    print("            mistake. Move it to G%d, or set Config->Dev Mode->UART Pins->RX=%d." % (rxpin, txpin))

if mode == "selftest":
    s.close()
    sys.exit(0 if ok else 1)

if not ok:
    print("\n(Skipping live test — fix the wiring above first.)")
    s.close(); sys.exit(1)

# ---- 3. live read test -----------------------------------------------------
print("\n== Live read test — HOLD A FOB ON THE COIL for %ds ==" % int(secs))
for n in (3, 2, 1):
    print("   starting in %d..." % n); time.sleep(1)
s.reset_input_buffer()
rd = ("gpio read %d\r\n" % rxpin).encode()
buckets = {}; tok = re.compile(rb'[01]')
start = time.time(); outstanding = 0
for _ in range(20):
    s.write(rd); outstanding += 1
print("   sec |  zeros | ones")
printed = -1
while time.time() - start < secs:
    data = s.read(4096)
    now = int(time.time() - start)
    b = buckets.setdefault(now, [0, 0])
    for m in tok.findall(data):
        if m == b'0': b[0] += 1
        else: b[1] += 1
        outstanding -= 1
    if now > printed and (now - 1) in buckets:
        z, o = buckets[now - 1]
        print("   %3d | %6d | %5d %s" % (now - 1, z, o, "  <<< TAG" if z > 0 else ""))
        printed = now
    need = 40 - outstanding
    if need > 0:
        s.write(rd * need); outstanding += need
s.close()

total0 = sum(v[0] for v in buckets.values())
total1 = sum(v[1] for v in buckets.values())
print("\n   totals: zeros=%d ones=%d" % (total0, total1))
if total0 > 3:
    print("   -> PASS: tag data toggling on G%d. The reader works end-to-end." % rxpin)
    print("\nNow read the UID on the device:  RFID -> Read 125kHz -> tap fob -> Select -> Save file")
    sys.exit(0)
else:
    print("   -> No toggling seen. Press the fob flat against the antenna coil and retry.")
    print("      (Self-test passed, so the wiring is right — this is just fob placement/range.)")
    sys.exit(1)
PY
