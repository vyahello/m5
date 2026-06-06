# 10. Using Bruce firmware

Your device now runs **Bruce v1.15** (confirmed over serial: `Device: M5StickC
Plus2`). This is the full usage guide: launching, the menus, the serial command
line, the web UI, scripting, and debugging.

> ⚠️ **Authorized use only.** Bruce's Wi-Fi/BLE/IR/RF features can disrupt other
> people's devices and networks. Use them only on equipment you own or have
> explicit written permission to test.

---

## TL;DR

- **It's a standalone gadget** — Bruce runs on the device with its own screen +
  buttons. No PC needed (runs on battery; press power to turn on).
- **You drive it three ways:** (1) on-device buttons, (2) **serial CLI** from this
  machine, (3) **web UI** over Wi-Fi.
- **Scripting is JavaScript (ES5), NOT Python.** See [Python?](#can-i-run-python-on-it) below.
- **Serial CLI quick start:**
  ```bash
  ./tools/bruce-cmd.sh info          # one-shot command + reply
  ./tools/bruce-cmd.sh "tone 4000 200"   # buzzer beep
  # or interactive:
  ./tools/free-port.sh && screen /dev/ttyACM0 115200    # type commands; Ctrl-A K Y to exit
  ```

---

## 1. Launching & navigating on the device

- **Power on:** press the power button (bottom-left side). Long-press to power off.
- Bruce boots to its **main menu** — a horizontal/vertical list of category icons.
- **Buttons (M5StickC Plus2) — verified from the 1.15 board config**
  (`SEL_BTN=37, UP_BTN=35, DW_BTN=39`):

  | Physical button | GPIO | Bruce action |
  |-----------------|------|--------------|
  | Big round **"M5" button (front face)** | 37 | **SELECT / Enter** (open / confirm / run) |
  | **Top button, right side** | 39 | **NEXT** (move selection forward; wraps around) |
  | **Power button, lower-left side** | 35 | **BACK / Esc** (tap); **hold ~6 s = power off** |

  There's no separate "previous" — cycle forward with the side button. The power
  button is also Back/Esc, so **tap it, don't hold**.

- **Navigating to run a script (e.g. `watchface.js`):** power on → tap **Next
  (side)** to highlight **Scripts** → press **M5 (Select)** → **Next** to the file
  → **Select** to run. Exit a running script with **any button press**.
- USB is **not** required to use Bruce — only for charging, serial CLI, or reflashing.

---

## 2. Main menu — what Bruce provides

Categories on the main menu (some only light up with extra hardware modules):

| Menu | What's inside | Needs extra HW? |
|------|---------------|-----------------|
| **WiFi** | **Connect Wifi** (join your network — 2.4 GHz only), host AP, **Target Atks** (recon, deauth, clone→Evil Portal, deauth+clone), **Beacon Spam** (funny/Rick-roll/random/custom SSIDs), **Deauth Flood**, **Evil Portal** (captive-portal cred harvest), Scan Hosts, TCP listener, ARP poison, TelNet, SSH, Wardriving, sniffers | No (built-in Wi-Fi) |
| **BLE** | BLE media control (phone screenshots, play/pause), BLE spam/beacons, BLE keyboard (HID), scan | No (built-in BLE) |
| **IR** | **TV-B-Gone**, send saved IR, receive/record IR | No (built-in IR LED) |
| **RF / SubGHz** | Read/replay/spectrum sub-GHz signals | **Yes — CC1101 module** |
| **RFID** | Read/write/emulate RFID/NFC tags | **Yes — RC522/PN532** |
| **FM** | FM broadcast | **Yes — FM module** |
| **NRF24 / LoRa / GPS** | 2.4 GHz tools, LoRa, GPS/wardriving | **Yes — respective modules** |
| **Files** | Browse/manage LittleFS (internal) + SD card (if attached): list/read/copy/delete | SD optional |
| **JS Interpreter / Scripts** | Run `.js` scripts from `/scripts` | No |
| **Clock / Connect / Config** | Clock UI, connections, settings & theming | No |

> On a bare StickC Plus2 (no add-on modules), the fully-functional categories are
> **WiFi, BLE, IR, Files, Scripts, Config**. RF/RFID/FM/LoRa/NRF24/GPS menus appear
> but need the matching hardware unit wired to the Grove/pin header.

---

## 3. Connecting & running commands via CLI (serial)

Bruce has a **serial command interface** modeled on the Flipper Zero CLI. This is
the "run commands on it from my terminal" path you wanted.

**Connection settings:** `115200` baud, 8 data bits, 1 stop bit, no parity, no flow
control, on `/dev/ttyACM0`.

### Easiest: the helper script

```bash
cd /home/kali/m5
./tools/bruce-cmd.sh info               # device info + reply
./tools/bruce-cmd.sh free               # heap + PSRAM
./tools/bruce-cmd.sh "tone 4000 200"    # buzzer beep
./tools/bruce-cmd.sh "storage list /"   # list files
./tools/bruce-cmd.sh uptime
WAIT=3 ./tools/bruce-cmd.sh "ir rx 3"   # listen 3s for an IR signal, print the dump
```

It frees the port, sends the command, and prints Bruce's reply.

### ⚠️ Command availability is build/hardware-specific

Not every command in the reference below is compiled into every build. **Tested on
this StickC Plus2 (Bruce v1.15):**

- ✅ Work: `info`, `uptime`, `free`, `date`, `settings`, `storage`, `tone`/`beep`
  (buzzer), `gpio mode/set`, `ir`, `power`, `clock`.
- ❌ Not in this build: `say` and `music_player` (need a real speaker/DAC — the
  Plus2 has only a passive buzzer; both return "Command not found"). Use
  `tone`/`beep` for sound (see `./tools/melody.sh` to play tunes). `led` is also absent
  (needs an RGB LED — the Plus2 has a single red LED only).
- ⚠️ `i2c` exists but the `scan` argument is rejected in this build.

An unsupported command returns `ERROR: Command not found at '<cmd>'` — that's the
build telling you it wasn't compiled in, not a bug in your syntax.

### Interactive

```bash
./tools/free-port.sh
screen /dev/ttyACM0 115200        # type a command, Enter; exit with Ctrl-A K Y
```

### Other ways (from the Bruce wiki)

```bash
# one-shot with busybox microcom
echo "say hi" | busybox microcom -s 115200 /dev/ttyACM0 -t 1000
# over the network once the WebUI is running (see §4)
curl -XPOST "http://bruce.local/cm" -d "cmnd=say hi"
```

### Command reference (the important ones)

| Command | Arguments | Does |
|---------|-----------|------|
| `info` | | firmware version, MAC, device, wifi state |
| `uptime` / `date` / `free` | | uptime / clock / free heap |
| `say` | `<text>` | text-to-speech (speaker) |
| `tone` / `beep` | `<freq> <duration>` | play a tone |
| `music_player` / `play` | `<file>` | play an audio file |
| `led` | `<r/g/b> <0-255>` | set UI accent color |
| `color` | | UI color control |
| `power` | `<off/reboot/sleep>` | power management |
| `clock` | | show clock UI |
| `screen` | | screen control |
| `gpio mode` | `<pin> <0/1>` | set pin input(0)/output(1) |
| `gpio set` | `<pin> <0/1>` | drive pin low(0)/high(1) |
| `i2c scan` | | scan I²C bus, list devices |
| `ir rx` | `<timeout s>` | record an IR signal, dump to serial |
| `ir tx` | `<protocol> <address> <value>` | send a decoded IR signal |
| `ir tx_from_file` | `<path>` | send a saved IR file |
| `subghz rx` / `rf rx` | `<timeout s>` | read RF (needs CC1101) |
| `subghz tx` / `rf tx` | `<value> <freq> <te> <count>` | send RF (needs CC1101) |
| `storage` | `list/read/write/copy/remove/mkdir/rename/md5` `<path>` | file management (aliases: `ls cat cp md rm ren`) |
| `settings` / `set` | `[name] [value]` | view/change settings |
| `factory_reset` | | reset `bruce.conf` to defaults |
| `badusb` | | HID injection (**needs native USB — not on ESP32-classic StickC Plus2**) |
| `js` | `<script path>` | run a JavaScript file (see §5) |
| `crypto` | | crypto helpers |
| `webui` | | start the web UI |
| `loader` | | firmware/app loader |

> Paths are **relative to storage root** (SD card if present, else internal
> LittleFS). Most commands match the [Flipper Zero CLI](https://docs.flipper.net/development/cli).

---

### Connecting to your Wi-Fi

The ESP32 is **2.4 GHz only** — it cannot join 5 GHz networks (use your router's
2.4 GHz SSID). Two ways:

- **On the device:** `WiFi → Connect Wifi` → pick your SSID → enter the password on
  the on-screen keyboard. Keyboard controls on the 3-button stick:
  **Next (side)** = move highlight, **Esc/power (tap)** = flip move direction,
  **M5 (front)** = type the key. Special keys: `CAP` (caps), `DEL` (backspace),
  `SPACE`, `OK` (finish/connect), `BACK` (cancel).
- **Over serial (no typing on device):** edit `SSID`/`PASS` in `apps/wifi-connect.js`,
  then `./tools/bruce-put.sh apps/wifi-connect.js /scripts/wifi-connect.js` and
  `./tools/bruce-cmd.sh "js /scripts/wifi-connect.js"`. Uses JS `wifi.connect(ssid, timeout, pwd)`.

Verify either way with `./tools/bruce-cmd.sh info` → `Wifi: connected` + IP. Connecting
is per-session; enable **`wifiAtStartup`** (Config) to reconnect on boot. Once
online, Bruce can NTP-sync the RTC, serve the Web UI, and `wifi.httpFetch(url)`.

### Sync the clock via NTP (after Wi-Fi is connected)

On the device: **Config → Clock → "Via NTP Set Timezone"** → set DST / 12-24h →
pick your **timezone** (NTP delivers UTC, so the timezone offset is required). It
queries `pool.ntp.org` and writes the RTC. Verify with `./tools/bruce-cmd.sh date`
(should show the real date, not year 2000). There is no serial command for this —
it's a device-menu action.

## 4. Web UI (control over Wi-Fi)

1. On the device: **WiFi → Connect** to your network (or start **WiFi AP**).
2. Start the web UI: on-device menu, or `./tools/bruce-cmd.sh webui`.
3. Browse to **`http://bruce.local`** (or the IP shown on-screen).
4. From there: file manager (upload/download scripts & captures) and a
   **"SerialCmd"** box that runs the same commands as §3. Or script it:
   ```bash
   curl -XPOST "http://bruce.local/cm" -d "cmnd=info"
   ```

---

## 5. Scripting — JavaScript (the on-device "programming")

Bruce embeds a **JavaScript interpreter** (`BruceJS`). You write `.js` files, drop
them in the device's **`/scripts`** folder, and run them from the **Scripts** menu
or `js <path>` over serial.

**Important — it's ES5 only:**
- ✅ `var` (❌ no `let`/`const`-only features)
- ✅ classic `for (var i…)` loops (❌ no `for…of`)
- ✅ `function(){}` (❌ no arrow functions `()=>{}`)
- modules via `require()`, e.g. `var ir = require('ir');` (❌ no `import`)
- ❌ no `Promise` / `async`/`await` / `setTimeout` / npm modules

**Available JS modules:** `globals`, `audio`, `badusb`, `device`, `dialog`,
`display`, `gpio`, `ir`, `keyboard`, `notification`, `serial`, `storage`,
`subghz`, `wifi`.

### ⚠️ The display API for v1.15 (verified on this device)

The online wiki shows newer helpers like `println()` and `display.fill()` —
**those are NOT in the 1.15 build** (they throw `ReferenceError: ... is not
defined`). The working API for *this* firmware, taken from the official
[`Example1.js`](https://github.com/pr3y/Bruce/blob/1.15/sd_files/interpreter/Example1.js)
shipped with 1.15:

```javascript
// hello.js — runs on this device (output appears on the TFT screen, not serial)
var display = require('display');
var device  = require('device');
var w = display.width(), h = display.height();

display.drawFillRect(0, 0, w, h, display.color(0, 0, 0));   // clear to black
display.setTextSize(2);
display.setTextColor(display.color(0, 255, 0));             // green
display.drawString("Hello World!", 8, 20);
display.setTextSize(1);
display.setTextColor(display.color(255, 255, 255));
display.drawString("Bruce JS on " + device.getBoard(), 8, 50);
display.drawString("Battery: " + device.getBatteryCharge() + "%", 8, 65);
display.drawRect(3, 3, w - 6, h - 6, display.color(150, 20, 210));
delay(6000);
```

Verified display methods (used in the official 1.15 example scripts): `width()`,
`height()`, `color(r,g,b)`, `fill(color)` (clear screen), `setTextSize(n)`,
`setTextColor(color)`, `setTextAlign(...)`, `drawString(text, x, y)`,
`drawText(...)`, `drawFillRect(x,y,w,h,color)`, `drawRect(x,y,w,h,color)`,
`createSprite(...)`. Globals: `delay(ms)`, `random(...)`, `now()`. Module `device`:
`getBoard()`, `getBatteryCharge()`. Module `keyboard`: `getSelPress()`,
`getEscPress()`, `getNextPress()`, `getPrevPress()`, `getAnyPress()`. Other
modules via `require('ir')`, `require('wifi')`, `require('storage')`, etc.

**Working examples in this repo** (all verified to run clean on the device):

| Script | What it does | Notes |
|--------|--------------|-------|
| `hello.js` | static info screen | runs once, exits |
| `demo.js` | animated: intro / info panel / loading bar / bouncing block | runs ~13s, exits |
| `watchface.js` | **battery + clock watchface** — ticking `HH:MM:SS`, date, battery bar | **loops** until a button press |

```bash
./tools/bruce-put.sh apps/demo.js /scripts/demo.js
./tools/bruce-cmd.sh "js /scripts/demo.js"        # watch the TFT (~13s)
./tools/bruce-put.sh apps/watchface.js /scripts/watchface.js
./tools/bruce-cmd.sh "js /scripts/watchface.js"   # ticks until you press a button
```

### Ready-made games

Bruce ships JS games in its 1.15 examples. Installed on this device (`/scripts/`)
and saved locally in `/home/kali/m5/apps/games/`:

| Game | Notes |
|------|-------|
| `arcade-games.js` | 92 KB multi-game collection **made for the StickC Plus2** |
| `pingpong.js` | Pong (verified running) |
| `space_shooter.js` · `dino_game.js` · `highway_racer.js` · `tamagochi.js` | individual games |

Launch from the device **Scripts** menu or `./tools/bruce-cmd.sh "js /scripts/pingpong.js"`.
Controls: **side button** = move/Next, **M5 (front)** = action/select, **power tap** =
back/exit. More at <https://github.com/pr3y/Bruce/tree/main/sd_files/interpreter>.

**Time on this device:** `now()` returns *uptime in milliseconds*, not wall-clock,
and this build supports **`Date.now()` only** (not `new Date()`). `watchface.js`
reads `Date.now()` (epoch ms, which tracks the RTC) and computes date/time itself.
For correct time you must **NTP-sync the RTC first** (Config → Clock → Via NTP Set
Timezone); until then the RTC reads year 2000 and the watchface shows a 2000 date.
Bruce stores *local* time in the system clock, so no extra TZ math is needed — but
`watchface.js` has a `TZ_FIX_HOURS` knob at the top if the time is off by whole
hours. A looping script (like the watchface) holds the device + serial CLI until a
button exits it — expected for a foreground loop.

> **Output goes to the screen, not serial.** Only uncaught errors print over
> serial — so a clean run with no `ReferenceError` means it worked; look at the
> device's TFT.

### Getting scripts onto the device

**This repo's helper** (`bruce-put.sh`) uploads a local file over the serial CLI —
it handles Bruce's line-based `storage write ... -size N` + `EOF` protocol for you:

```bash
./tools/bruce-put.sh apps/hello.js /scripts/hello.js     # upload
./tools/bruce-cmd.sh "js /scripts/hello.js"         # run it
./tools/bruce-cmd.sh "storage list /scripts"        # confirm it's there
```

Other routes: the **Web UI** file manager (§4), an **SD card** with a `/scripts`
folder, or raw `storage write -filepath <path> -size <bytes>` then sending the
bytes and a final `EOF` line. Scripts in **`/scripts`** also appear in the
on-device **Scripts** menu so you can launch them with the buttons.

---

## Can I run Python on it?

**No.** Bruce's scripting language is **JavaScript (ES5)**, not Python. There's no
Python interpreter in Bruce. Your options:

- **Want Bruce's pentest tools** → script them in **Bruce JS** (§5) or drive them
  via the **serial CLI** (§3) / web UI (§4) from your machine.
- **Want actual Python on the device** → that's a *different firmware*
  (**MicroPython / UIFlow**), which would **replace Bruce**. You can't have Bruce
  and a Python REPL at the same time — it's one firmware or the other (out of scope
  for this Bruce-focused workspace).

So: you *can* control and program the device "from cmd," just in JavaScript +
Bruce commands, not Python.

---

## 6. Debugging Bruce

- **Read its serial output:** `./tools/free-port.sh && screen /dev/ttyACM0 115200`.
  Bruce prints boot info and command replies here (115200 baud).
- **Quick health check:** `./tools/bruce-cmd.sh info` / `./tools/bruce-cmd.sh free` (free heap).
- **A feature misbehaves:** `./tools/bruce-cmd.sh factory_reset` resets `bruce.conf`
  to defaults (settings only — doesn't wipe firmware).
- **Frozen/unresponsive:** `./tools/bruce-cmd.sh "power reboot"`, or hold the power
  button to force off, then power on.
- **Boot loop / blank screen after an update:** usually a wrong/corrupt flash —
  reflash the correct StickC Plus2 build (see below).
- **Port busy:** something else holds `/dev/ttyACM0` → `./tools/free-port.sh`.

---

## 7. Reflashing / restoring

- **Update Bruce / reflash:**
  ```bash
  ./tools/free-port.sh && source venv/bin/activate
  esptool --port /dev/ttyACM0 --baud 921600 write-flash 0x0 firmware/Bruce-m5stack-cplus2.bin
  ```
- **Back to factory** (only if you saved a backup — see [03-flashing-bruce.md](03-flashing-bruce.md)):
  ```bash
  ./tools/free-port.sh && source venv/bin/activate
  esptool --port /dev/ttyACM0 erase-flash
  esptool --port /dev/ttyACM0 --baud 921600 write-flash 0x0 m5stickcplus2-factory-full-8MB.bin
  ```

---

## Helper scripts in this repo

| Script | Purpose |
|--------|---------|
| `./tools/free-port.sh` | release `/dev/ttyACM0` from any monitor before flashing/CLI |
| `./tools/bruce-cmd.sh <cmd>` | send a Bruce serial command and print the reply |
| `./tools/bruce-put.sh <local> <device-path>` | upload a file (e.g. a `.js` script) to Bruce storage |
| `./tools/bruce-get.sh <device-path> [local-dest]` | download a file from the device via the Web UI (binary-safe — pcaps, dumps) |
| `./tools/bruce-rm.sh <device-path> [...]` | delete one or more files from Bruce storage |
| `./tools/bruce-shell.sh` | interactive serial console — type commands live (exit: Ctrl-]) |
| `./tools/melody.sh [twinkle\|mario\|zelda\|scale\|"C4:300 ..."]` | play a melody on the buzzer via `tone` |

Full docs: <https://wiki.bruce.computer/> · Source: <https://github.com/pr3y/Bruce>
