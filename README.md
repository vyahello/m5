# M5StickC Plus2 — Bruce workspace

Workspace for an **M5StickC Plus2** (ESP32) running the **[Bruce](https://github.com/pr3y/Bruce)**
firmware, driven from this Kali Linux machine over USB serial.

> **This unit:** ESP32-PICO-V3-02 · 8 MB flash · Wi-Fi (2.4 GHz) + BT · MAC
> `c0:cd:d6:14:9f:3c` · USB-serial CH9102 → **`/dev/ttyACM0`** ·
> currently flashed with **Bruce v1.15**.

> ⚠️ Bruce's Wi-Fi/BLE/IR tools are for devices/networks you own or are
> authorized to test.

---

## Layout

```
m5/
├── README.md                 # this file
├── CLAUDE.md                 # context for Claude Code
├── docs/                     # the guide (device → connect → flash → use)
│   ├── 01-device.md
│   ├── 02-connecting.md
│   ├── 03-flashing-bruce.md
│   ├── 04-using-bruce.md     # main usage reference
│   ├── 05-troubleshooting.md
│   ├── 06-pentesting.md      # pentest field guide (Wi-Fi/BLE/IR + add-ons)
│   └── 07-tips-and-tricks.md # get the most out of the device
├── firmware/
│   └── Bruce-m5stack-cplus2.bin   # Bruce 1.15, StickC Plus2 (flash @ 0x0)
├── tools/                    # serial helper scripts (use the venv automatically)
│   ├── free-port.sh          # release /dev/ttyACM0
│   ├── bruce-cmd.sh          # send one command, print reply
│   ├── bruce-shell.sh        # interactive serial console
│   ├── bruce-put.sh          # upload a file to the device
│   ├── bruce-rm.sh           # delete file(s) on the device
│   └── melody.sh             # play tunes on the buzzer
├── apps/                     # JavaScript apps for the device (run via Bruce JS)
│   ├── hello.js  demo.js  watchface.js  wifi-connect.js
│   └── games/                # pingpong, dino, space_shooter, arcade-games, ...
└── venv/                     # esptool + pyserial
```

---

## Quick start

The device already runs Bruce. From the repo root (`/home/kali/m5`):

```bash
# Talk to it (one-shot)
./tools/bruce-cmd.sh info                 # Bruce version, device, wifi, IP

# Interactive serial console (exit: Ctrl-])
./tools/bruce-shell.sh

# Upload + run a JS app
./tools/bruce-put.sh apps/watchface.js /scripts/watchface.js
./tools/bruce-cmd.sh "js /scripts/watchface.js"

# Make some noise
./tools/melody.sh mario
```

**Golden rule:** only one program can hold `/dev/ttyACM0`. If you get "busy" or no
reply, run `./tools/free-port.sh` (PC side) or press a button on the device to exit
a running script. See [docs/05-troubleshooting.md](docs/05-troubleshooting.md).

---

## Docs

1. [The device](docs/01-device.md) — specs, peripherals, buttons
2. [Connecting](docs/02-connecting.md) — USB, serial, permissions, the port rule
3. [Flashing Bruce](docs/03-flashing-bruce.md) — esptool, the image, partitions, backup
4. [Using Bruce](docs/04-using-bruce.md) — menus, serial CLI, web UI, Wi-Fi, clock, JS scripting, games
5. [Troubleshooting](docs/05-troubleshooting.md) — the common failure modes
6. [Pentesting](docs/06-pentesting.md) — Wi-Fi/BLE/IR attacks, on-LAN MITM, exfil, add-on modules, engagement workflow
7. [Tips & tricks](docs/07-tips-and-tricks.md) — port rules, battery, scripting, backups, getting max value
