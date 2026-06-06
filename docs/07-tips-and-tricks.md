# 7. Tips & tricks — getting the most out of the device

Hard-won, verified tips for living with this **M5StickC Plus2 + Bruce v1.15** day
to day. Pentest-specific tactics are in [06-pentesting.md](06-pentesting.md); this
is the general "use it well" knowledge.

---

## The two rules that fix 90% of problems

1. **One process owns `/dev/ttyACM0` at a time.** A `screen`/monitor/Web-UI-less
   serial tool holding the port → everything else gets "busy" / "(no reply)". Fix:
   ```bash
   ./tools/free-port.sh
   ```
2. **A looping script/game on the device starves the serial CLI.** `free-port.sh`
   **can't** fix this — the blocker is *on the device*. **Press any button on the
   device** to exit the running script, then serial works again.

Internalize these two and most "it's broken" moments evaporate.

---

## Serial workflow

- **One-shot vs. live:** `bruce-cmd.sh <cmd>` for a single command + reply;
  `bruce-shell.sh` for an interactive console (exit **Ctrl-]**).
- **No reply? Wait longer:** scans/IR/Wi-Fi take time — `WAIT=4 ./tools/bruce-cmd.sh info`
  (default WAIT is 1.5 s). Bump to `WAIT=6` for slow ops.
- **Quote multi-word commands:** `./tools/bruce-cmd.sh "storage list /scripts"`.
- **Stable port path:** if `/dev/ttyACM0` ever renumbers, use the by-id path
  `/dev/serial/by-id/usb-1a86_USB_Single_Serial_5B1E047086-if00` (survives replug).
- **Storage aliases save typing:** `ls cat cp md rm ren` map to
  `storage list/read/copy/mkdir/remove/rename`.
- **Health one-liners:** `info` (version/MAC/IP), `free` (heap+PSRAM), `uptime`.

---

## File management

- **Upload:** `./tools/bruce-put.sh <local> /scripts/<name>.js` (handles Bruce's
  `storage write -size N` + `EOF` protocol for you).
- **Delete:** `./tools/bruce-rm.sh /scripts/old.js` (accepts multiple paths).
- **Inspect text:** `./tools/bruce-cmd.sh "storage read /file.txt"`.
- **Binaries (pcap, images):** use the **Web UI file manager** — serial `read`
  mangles non-text; the Web UI downloads bytes cleanly.
- **3 MB is the whole filesystem** (no SD slot). Watch it with `storage list` /
  `free`; prune with `bruce-rm.sh`. Add an **SD HAT** if you need real space.
- **`/scripts` is special:** anything there shows up in the on-device **Scripts**
  menu so you can launch it with the buttons — drop your go-to tools there.

---

## Power & battery

- **~200 mAh** — small. Wi-Fi/BLE attacks chew through it; expect short standalone
  runtime. **Carry a USB-C power bank** for field use (it runs while charging).
- **Power button doubles as Back/Esc** — **tap** to go back, **hold ~6 s** to power
  off. Easy to power off by accident when you meant "back"; tap deliberately.
- **Reboot/sleep over serial:** `./tools/bruce-cmd.sh "power reboot"` /
  `"power off"` / `"power sleep"`.
- **Frozen device:** hold power ~6 s to force off, then press to power on. A half-
  flash is never bricked — worst case, reflash.
- **Dim the screen / shorten timeouts** in Config to stretch battery on long jobs.

---

## Navigation muscle memory (3 buttons)

| Button | GPIO | Action |
|--------|------|--------|
| Front round **M5** | 37 | **Select / Enter / action** |
| Side **top** | 39 | **Next** (cycles forward; wraps) |
| Side **power** | 35 | **Back/Esc** (tap) · **power off** (hold) |

There's **no "previous"** — cycle forward with the side button until it wraps.
On the **on-screen keyboard**: Next = move highlight, power-tap = flip move
direction, M5 = type; `OK` finishes, `DEL` backspaces, `CAP` toggles caps.

---

## Make it boot ready-to-go

- **`wifiAtStartup`** (Config) → auto-reconnects Wi-Fi on boot, so the Web UI / NTP
  / `httpFetch` work the moment it powers on.
- **Auto-launch a script on boot:** set a startup app in Config so the device comes
  up straight into your watchface / sensor / tool — handy for a single-purpose
  field gadget.
- Keep your **most-used JS in `/scripts`** so they're one Scripts-menu hop away.

---

## Clock / time (the gotcha)

- The serial **`date` command is buggy** — it reports **year 2000** even when the
  clock is correct. **Don't trust it**; trust `Date.now()` and the on-screen clock.
- Real time needs **NTP**: connect Wi-Fi → **Config → Clock → Via NTP Set Timezone**
  → pick timezone (NTP gives UTC; offset is required). Your TZ = **Kyiv (UTC+2,
  DST→+3)**. `watchface.js` reads the synced RTC via `Date.now()`.

---

## JavaScript scripting tips

- **It's ES5** — `var` only, classic `for` loops, `function(){}`. **No** `let`/
  `const`-isms, arrow functions, `Promise`, `async`, `setTimeout`, or npm.
- **Use the verified 1.15 API**, not the wiki's newer one. `println()` and
  `new Date()` **throw** — use `display.drawString(...)` and `Date.now()`. Full
  verified surface in [04-using-bruce.md §5](04-using-bruce.md).
- **Output goes to the TFT, not serial.** A clean serial run (no `ReferenceError`)
  = success — **look at the screen**. Only uncaught errors print over serial.
- **Debug by drawing:** no `console.log` to serial → `display.drawString` your
  values on screen, or throw to force a serial error.
- **`now()` ≠ wall clock** — it's uptime ms. Use `Date.now()` for epoch time.
- **Iterate fast:** edit locally in `apps/`, then
  `./tools/bruce-put.sh apps/x.js /scripts/x.js && ./tools/bruce-cmd.sh "js /scripts/x.js"`.
- Keep working apps under version control in `apps/`; the device is disposable, the
  repo is the source of truth.

---

## Remote control over Wi-Fi (Web UI)

- Start it: `./tools/bruce-cmd.sh webui` → browse `http://<ip>` (or `bruce.local`).
  Default creds **`admin` / `bruce`** — change them.
- **Best for file management** (upload/download/edit, esp. binaries).
- **curl needs the session cookie**, not Basic Auth:
  ```bash
  curl -s -c /tmp/b.cookies -d "username=admin&password=bruce" http://<ip>/login -o /dev/null
  curl -s -b /tmp/b.cookies -XPOST http://<ip>/cm -d "cmnd=info"
  ```
- **`/cm` returns "queued", not output** — replies appear on the device. To *read*
  command output, use serial (`bruce-cmd.sh`). The Web UI **Run button 400s** on
  this build — launch scripts via serial or the Scripts menu instead.

---

## Audio feedback (buzzer only)

- **No speaker/DAC** → `say`/`music_player` are absent. Use `tone`/`beep`:
  ```bash
  ./tools/bruce-cmd.sh "tone 4000 200"      # 4 kHz, 200 ms
  ./tools/melody.sh mario                    # twinkle | mario | zelda | scale | "C4:300 ..."
  ```
- Use short tones as **audible status cues** in your own scripts/automation (e.g.
  beep on "handshake captured", different beep on "done").

---

## Commands/features NOT on this hardware (stop retrying them)

These return `Command not found` / `ReferenceError` because the **hardware isn't
there**, not because you mistyped:

- `say`, `music_player` → no speaker/DAC (buzzer only).
- `led` → no RGB LED (single red LED; set UI accent via Config).
- `badusb` HID-over-USB → ESP32-**classic** has no native USB (needs S2/S3).
- `i2c scan` → arg rejected in this build (scan from JS or laptop).
- SubGHz / RFID / NRF24 / FM / LoRa / GPS menus → need **add-on modules**
  ([06 §9](06-pentesting.md)).
- `println()`, `new Date()` in JS → not in the 1.15 interpreter.

---

## Backup discipline

- **Two images live in `firmware/`** (gitignored — they're large):
  `Bruce-m5stack-cplus2.bin` (clean app) and `m5-bruce-full-8MB-<date>.bin`
  (full snapshot incl. settings/Wi-Fi/`/scripts`).
- **Snapshot before risky changes / between engagements:**
  ```bash
  ./tools/free-port.sh && source venv/bin/activate
  esptool --port /dev/ttyACM0 --baud 921600 read-flash 0x0 0x800000 \
    firmware/m5-bruce-full-8MB-$(date +%Y%m%d).bin
  ```
- **Restore a known-good state:**
  ```bash
  esptool --port /dev/ttyACM0 --baud 921600 write-flash 0x0 \
    firmware/m5-bruce-full-8MB-20260606.bin
  ```
- ⚠️ **No factory image exists** — these restore *Bruce*, not the M5 demo. For
  factory you'd reflash via **M5Burner**.

---

## esptool / flashing gotchas

- **Hyphen subcommands** (esptool v5): `flash-id`, `write-flash`, `erase-flash`,
  `read-flash`.
- **Never `sudo` esptool** — it breaks the venv python. User `kali` is in
  `dialout`, so no sudo is needed for `/dev/ttyACM0`.
- **Close monitors first** (`free-port.sh`) or flashing fails "busy".
- Keep `--baud 921600` for speed; drop to `115200` only if it errors.

---

## Quick wins to try right now

```bash
./tools/bruce-cmd.sh info                         # confirm it's alive + IP
./tools/bruce-cmd.sh "storage list /scripts"      # see installed tools/games
./tools/bruce-cmd.sh "js /scripts/watchface.js"   # turn it into a watch (button to exit)
./tools/melody.sh zelda                           # because you can
```

➡️ See also: [6. Pentesting](06-pentesting.md) · [4. Using Bruce](04-using-bruce.md)
· [5. Troubleshooting](05-troubleshooting.md)
