# CLAUDE.md

Context for Claude Code working in `/home/kali/m5`.

## What this is

A workspace for an **M5StickC Plus2** (ESP32) running **Bruce v1.15** firmware,
driven over USB serial from this Kali machine. Bruce-focused: flashing → usage.
Docs in `docs/`, helper scripts in `tools/`, JS apps in `apps/`, firmware in
`firmware/`.

> ⚠️ **Educational / authorized use only.** This workspace exists for the owner's
> own cybersecurity learning and for **authorized** penetration-testing engagements
> (signed scope). The offensive features here — Evil Portal credential capture,
> deauth/netcut, responder/LLMNR poisoning, handshake sniffing/brucegotchi, ARP
> spoofing — are to be run **only** against the owner's own lab devices/networks or
> targets with explicit written permission. Not for use against third parties.

## Repo layout

```
docs/      01-device · 02-connecting · 03-flashing-bruce · 04-using-bruce ·
           05-troubleshooting · 06-pentesting · 07-tips-and-tricks
firmware/  Bruce-m5stack-cplus2.bin (flash @ 0x0) + full 8MB snapshot
           — *.bin gitignored, large
tools/     free-port.sh bruce-cmd.sh bruce-shell.sh bruce-put.sh bruce-get.sh
           bruce-rm.sh portals-set-ap.sh melody.sh
apps/      hello.js demo.js watchface.js wifi-connect.js + games/
portals/   Evil Portal HTML templates (→ /PortalTemplates on the device)
venv/      esptool v5.3.0 + pyserial — gitignored
loot/      captures pulled off the device — gitignored (client evidence)
```

Scripts compute `ROOT` (repo root) and find `venv/` + `free-port.sh` by absolute
path, so they work when called as `./tools/<script>` from the repo root and accept
relative file args (e.g. `apps/hello.js`).

## Device (probed)

- **M5StickC Plus2** · ESP32-PICO-V3-02 rev v3.1 · dual-core 240 MHz · 8 MB flash ·
  2 MB PSRAM · Wi-Fi b/g/n **(2.4 GHz only)** + BT/BLE · MAC `c0:cd:d6:14:9f:3c`.
- USB-serial **CH9102** (`1a86:55d4`) → **`/dev/ttyACM0`** (CDC-ACM, not ttyUSB).
  Stable: `/dev/serial/by-id/usb-1a86_USB_Single_Serial_5B1E047086-if00`.
- LAN IP (last seen): `192.168.1.111`.
- Buttons (Bruce build): `SEL_BTN=37` (front M5 = Select), `DW_BTN=39` (side top =
  Next), `UP_BTN=35` (power = Back/Esc; hold ~6 s = off).
- Partitions after Bruce: nvs@0x9000 · app0@0x10000 (~4.9 MB) · LittleFS@0x4f0000
  (**3 MB user storage** `/scripts`) · coredump@0x7f0000. No SD slot.

## Environment

- `/dev/ttyACM0` is `root:dialout` (660); user `kali` is in `dialout` → **no sudo**.
  Never sudo esptool (breaks venv python).
- `source venv/bin/activate` for raw esptool; the `tools/` scripts use the venv
  automatically.
- esptool v5 uses hyphen subcommands (`flash-id`, `write-flash`, `erase-flash`).

## Helper scripts (`tools/`)

- `free-port.sh [PORT]` — release the serial port from any screen/monitor.
- `bruce-cmd.sh <cmd>` — send a Bruce serial command, print reply (115200). Env
  `WAIT` (default 1.5; use `WAIT=4` if no reply).
- `bruce-shell.sh` — interactive serial console (pyserial miniterm). Exit Ctrl-].
- `bruce-put.sh <local> <device-path>` — upload a file (handles Bruce's
  `storage write -size N` + `EOF` line protocol).
- `bruce-get.sh [--serial|--flash] <device-path> [local-dest]` — download a file
  FROM the device. Default **web** mode = Web UI `/file?action=download`
  (binary-safe; auto-detects IP over serial + auto-starts webui; env
  `IP`/`WEBUSER`/`WEBPASS`/`FS`/`NOSTART`). **`--serial`** = `storage read` over
  USB, **no Wi-Fi**, **text-only** (truncates at NUL + size cap; refuses binary
  w/o `--force`; strips `\r`). **`--flash`** = **binary-safe + no Wi-Fi**: esptool
  dumps the LittleFS partition (cached `/tmp/bruce-littlefs.bin`, `--redump` to
  refresh) + littlefs-python extracts — byte-exact, the way to pull pcaps over USB.
- `bruce-rm.sh <device-path> [...]` — delete file(s) (`storage remove -filepath`).
- `portals-set-ap.sh <AP_NAME> [file ...]` — bake the magic first line
  `<!-- AP="..." -->` (Evil Portal rogue-AP SSID) into `portals/*.html` (idempotent —
  swaps, never stacks) + push to `/PortalTemplates/`. `--clear` (or `--none`) instead
  of a name **removes** the AP line (no baked SSID → Bruce default / on-device prompt).
  Env `PUSH=0` (edit local only), `DESTDIR` (device folder). Validates SSID ≤32 chars,
  no `"`.
- `melody.sh [twinkle|mario|zelda|scale|"C4:300 ..."]` — play tunes on the buzzer.

## Bruce specifics (learned & verified)

- Serial CLI = Flipper-style commands @ 115200 (`info`, `free`, `uptime`, `tone`,
  `storage list/read/write/remove`, `settings`, `gpio`, `ir`, `js`, `webui`, ...).
- **Not in this build** (hardware): `say`, `music_player` (no speaker/DAC — only a
  passive buzzer → use `tone`/`beep`/`melody.sh`); `led` (no RGB LED).
- **One owner of the port.** A monitor/`screen` blocks the CLI → `free-port.sh`. A
  **looping script/game on the device starves the serial CLI** → press a device
  button to exit it (free-port can't help there).
- **Scripting = JavaScript ES5**, not Python. Run `js /scripts/x.js`. Output goes
  to the **TFT screen**, not serial (only uncaught errors print on serial → a clean
  run = success). Build with the **verified 1.15 API**: `require('display')` →
  `width/height/color/fill/setTextSize/setTextColor/drawString/drawFillRect/
  drawRect`; globals `delay/now/random/Math`; `require('device').getBoard()/
  getBatteryCharge()`; `require('keyboard').getAnyPress()/...`. **Not available:**
  `println()` (global), `new Date()` → use `display.drawString` / `Date.now()`.
- **Time:** RTC NTP-synced via Config → Clock → Via NTP Set Timezone (device menu
  only; no serial cmd). User TZ = **Kyiv (UTC+2, DST→+3)**. `watchface.js` reads
  `Date.now()` (correct local time verified), `TZ_FIX_HOURS=0`. **Quirk:** the
  serial `date` command shows year 2000 even when synced — trust `Date.now()` /
  on-screen clock, not `date`.
- **Wi-Fi:** 2.4 GHz only. Connect via device WiFi menu or `apps/wifi-connect.js`
  (`wifi.connect(ssid, timeout, pwd)`).
- **Web UI:** `http://<ip>` (default creds `admin`/`bruce`). Cookie-session auth
  (curl: POST `/login` then use the `BRUCESESSION` cookie on `/cm`). Good for file
  management; its **Run button 400s** (launch scripts via serial/device instead);
  `/cm` returns "queued", not command output.
- **Exfil / pulling files off:** serial `storage read` is **text-only** (Bruce's
  `readString()` truncates at the first NUL → corrupts binary; small size cap →
  "File is too big"). Three routes, use `bruce-get.sh`: web mode (Web UI
  `/file?action=download`, binary-safe), `--serial` (USB, text-only), **`--flash`**
  (**binary loot over USB, no Wi-Fi**: esptool dumps the LittleFS partition
  `read-flash 0x4f0000 0x300000` + **littlefs-python** `block_size=4096` extracts —
  byte-exact, verified to recover pcaps). Handshakes
  save to `/BrucePCAP/handshakes/HS_<BSSID>_<SSID>.pcap`; crack on Kali with
  `aircrack-ng`/`hashcat -m 22000`. Loot dir `loot/` + `*.pcap`/`*_creds.csv` are
  gitignored.

## Apps on device (`/scripts`) and in `apps/`

`hello.js` (static), `demo.js` (animated, exits), `watchface.js` (battery+clock,
loops until button), `wifi-connect.js`, plus games in `apps/games/`
(`pingpong`, `dino_game`, `space_shooter`, `highway_racer`, `tamagochi`,
`arcade-games` = StickC Plus2 collection). Launch from device Scripts menu or
`./tools/bruce-cmd.sh "js /scripts/<name>.js"`.

## Status

- [x] Bruce v1.15 flashed (`firmware/Bruce-m5stack-cplus2.bin` @ 0x0) & verified.
- [x] Wi-Fi connected, RTC NTP-synced (Kyiv), watchface reads RTC.
- [x] Helper scripts + JS apps + games in place; docs reorganized (Bruce-only).
- [x] Full 8 MB device snapshot backed up: `firmware/m5-bruce-full-8MB-20260606.bin`
  (includes NVS/Wi-Fi/LittleFS). Restore: `write-flash 0x0 <that file>`.
- [ ] No *factory* firmware backup exists — reverting to the M5 demo needs an
  M5Burner image; the snapshot above restores Bruce, not factory.

## Gotchas recap

- One process owns the port at a time (`free-port.sh`).
- Looping device scripts block the serial CLI (button to exit).
- esptool: hyphen subcommands, no sudo, close monitors first.
- `say`/`music_player`/`led` absent on this hardware; `println`/`new Date()` absent
  in this JS build.
