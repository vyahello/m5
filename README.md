# 🦾 M5StickC Plus2 — Bruce Workspace

> A pentest multitool that fits on your keychain — plus the field notes to actually drive it.

A complete workspace for an **M5StickC Plus2** (ESP32) running the
**[Bruce](https://github.com/pr3y/Bruce)** firmware, controlled from **Kali Linux**
over USB serial. Everything from flashing the firmware to running Wi-Fi / BLE / IR
field work, with a set of helper scripts that make the device a pleasure to drive
from the terminal.

> ⚠️ **Educational & authorized use only.** Bruce's Wi-Fi/BLE/IR/RF tooling
> transmits and disrupts real devices. Use it **only** on hardware and networks you
> own or have **explicit written permission** to test.

**This unit:** ESP32-PICO-V3-02 · 8 MB flash · Wi-Fi 2.4 GHz + BT/BLE · on-board IR
· USB-serial CH9102 → `/dev/ttyACM0` · flashed with **Bruce v1.15**.

---

## ⚡ Quick start

The device already runs Bruce. From the repo root (`/home/kali/m5`):

```bash
./tools/bruce-cmd.sh info                          # version, device, wifi, IP
./tools/bruce-shell.sh                             # live serial console (exit: Ctrl-])

./tools/bruce-put.sh apps/watchface.js /scripts/watchface.js   # upload a JS app...
./tools/bruce-cmd.sh "js /scripts/watchface.js"               # ...and run it

./tools/melody.sh mario                            # make some noise 🎵
```

> 📟 **The one golden rule:** only one program can hold `/dev/ttyACM0` at a time.
> If you get *"busy"* or *"(no reply)"*, run `./tools/free-port.sh` (PC side) or
> press a button on the device to exit a running script.
> → [Troubleshooting](docs/05-troubleshooting.md)

---

## 🧭 The guide

Read top-to-bottom the first time, or jump to what you need:

| # | Doc | Read it when you want to… |
|---|-----|---------------------------|
| 1 | [The device](docs/01-device.md) | know the specs, peripherals & button map |
| 2 | [Connecting](docs/02-connecting.md) | get USB/serial working & permissions sorted |
| 3 | [Flashing Bruce](docs/03-flashing-bruce.md) | (re)flash firmware, understand partitions, back up |
| 4 | [Using Bruce](docs/04-using-bruce.md) | drive the menus, serial CLI, Web UI, clock & **JS scripting** |
| 5 | [Troubleshooting](docs/05-troubleshooting.md) | fix the common "it's broken" moments |
| 6 | [**Pentesting**](docs/06-pentesting.md) | Wi-Fi/BLE/IR attacks, on-LAN MITM, exfil, add-on modules |
| 7 | [Tips & tricks](docs/07-tips-and-tricks.md) | get the most out of the device day-to-day |

---

## 🎯 What it can do (out of the box)

The bare Plus2's real arsenal is **Wi-Fi + BLE + IR** — no add-on modules needed:

- **Wi-Fi** — recon/scan, deauth, beacon spam, **Evil Portal** credential capture,
  Karma, handshake/PMKID sniffing, and on-LAN tools (ARP poison, NetCut, Responder,
  TCP/Telnet/SSH, WireGuard, SOCKS proxy) once you join a network.
- **BLE** — scan, advert spam, **HID keyboard** injection (lab payloads in
  [`badble/`](badble/)), media hijack.
- **IR** — TV-B-Gone, capture & replay remotes.

Sub-GHz, RFID/NFC, NRF24, GPS, LoRa, FM appear in the menus but need cheap add-on
modules. Full honest breakdown in [docs/06 §0](docs/06-pentesting.md#0-know-your-actual-attack-surface).

---

## 🛠️ Helper scripts (`tools/`)

All scripts find the venv + serial port automatically — run them from the repo root.

| Script | Does |
|--------|------|
| `free-port.sh` | release `/dev/ttyACM0` from any monitor/screen |
| `bruce-cmd.sh <cmd>` | send one serial command, print the reply |
| `bruce-shell.sh` | interactive serial console (exit: Ctrl-]) |
| `bruce-put.sh <local> <device-path>` | upload a file to the device |
| `bruce-get.sh [--serial\|--flash] <path> [dest]` | download a file (Web UI binary-safe / USB text / USB binary) |
| `bruce-rm.sh <path> [...]` | delete file(s) on the device |
| `portals-set-ap.sh <AP> [files…]` | set the Evil Portal AP SSID on `portals/*.html` & push them |
| `melody.sh [mario\|zelda\|…]` | play tunes on the buzzer 🎵 |

---

## 🎮 Apps & games

JavaScript (ES5) apps in [`apps/`](apps/) — upload to `/scripts` and launch from the
device **Scripts** menu or over serial:

- `watchface.js` — battery + ticking clock · `demo.js` — animated demo ·
  `hello.js` — info screen · `wifi-connect.js` — join Wi-Fi from serial
- [`apps/games/`](apps/games/) — pingpong, dino, space shooter, highway racer,
  tamagochi, and a StickC-Plus2 arcade collection

> Bruce JS is **ES5, not Python**, and output goes to the **screen, not serial**.
> See the verified 1.15 API in [docs/04 §5](docs/04-using-bruce.md#5-scripting--javascript-the-on-device-programming).

---

## 📂 Layout

```
m5/
├── docs/        the guide (device → connect → flash → use → pentest → tips)
├── tools/       serial helper scripts (use the venv automatically)
├── apps/        JavaScript apps + games for the device
├── portals/     Evil Portal HTML templates (→ /PortalTemplates on the device)
├── badble/      Bad-BLE HID payloads for phone testing (benign, lab-safe)
├── firmware/    Bruce build + full device snapshot  (*.bin gitignored — large)
├── loot/        captures pulled off the device       (gitignored — client evidence)
└── venv/        esptool + pyserial                   (gitignored — regenerable)
```

---

<sub>Bruce firmware by [@pr3y](https://github.com/pr3y/Bruce) · wiki at
<https://wiki.bruce.computer/>. This is an independent personal workspace, not
affiliated with the Bruce or M5Stack projects.</sub>
