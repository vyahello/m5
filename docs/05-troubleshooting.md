# 5. Troubleshooting

## `/dev/ttyACM0` doesn't appear
- **Cable:** many USB-C cables are charge-only — use a data cable. Confirm with
  `lsusb | grep 1a86`.
- **Watch enumeration:** `sudo dmesg -w`, then plug in → expect `cdc_acm ... ttyACM0`.
- If it moved, use `/dev/serial/by-id/usb-1a86_USB_Single_Serial_5B1E047086-if00`.

## "Device or resource busy" / esptool can't connect
Only one program can own the port. A serial monitor or detached `screen` is
holding it:
```bash
./tools/free-port.sh        # kills screen/monitors, frees the port
```

## Serial command returns "(no reply)" / nothing
1. **A script/game is running on the device.** A looping script (game, watchface)
   starves Bruce's serial CLI. **Press a button on the device to exit it**, then
   retry. `free-port.sh` can't fix this — the blocker is on the device, not the PC.
2. **Too-short wait:** `WAIT=4 ./tools/bruce-cmd.sh info`.
3. **Frozen device:** hold the power button ~6 s to power off, press to power on.

## "ERROR: Command not found at '...'"
The command isn't compiled into this build (hardware-dependent), not a typo:
- `say`, `music_player` → need a real speaker/DAC; the Plus2 has only a buzzer →
  use `tone`/`beep` (or `./tools/melody.sh`).
- `led` → needs an RGB LED; the Plus2 has one red LED only → set UI colour via
  the device Config menu.

## JS script errors with "ReferenceError: ... is not defined"
The function isn't in this build. Use the **verified 1.15 API** (see
[04-using-bruce.md](04-using-bruce.md) §5): `display.drawString/drawFillRect/
drawRect/fill/color/setTextSize/setTextColor`, globals `delay/now`, and modules
via `require('device'|'keyboard'|'wifi'|...)`. `println()`/`new Date()` are **not**
available (use `display.drawString` / `Date.now()`).

## Web UI returns 401 "Unauthorized" (curl)
It uses a login **session cookie** (default creds `admin`/`bruce`), not Basic Auth:
```bash
curl -s -c /tmp/bruce.cookies -d "username=admin&password=bruce" http://<ip>/login -o /dev/null
curl -s -b /tmp/bruce.cookies -XPOST http://<ip>/cm -d "cmnd=info"
```
Note `/cm` returns "command queued" — output appears on the device, **not** in the
HTTP response. To read replies, use `./tools/bruce-cmd.sh` over serial.

## Web UI "Run" button gives 400
Launching JS from the Web UI is flaky on this build. Use the Web UI for **file
management** (upload/download/edit); **launch scripts** via
`./tools/bruce-cmd.sh "js /scripts/x.js"` or the device Scripts menu.

## Clock shows the wrong time
- The serial **`date` command is buggy** — it reads a stale clock and shows year
  2000 even when time is correct. Trust `Date.now()` and the on-screen clock.
- Real time needs **NTP sync**: Wi-Fi connected → **Config → Clock → Via NTP Set
  Timezone → pick timezone** (NTP gives UTC; timezone is required). The watchface
  reads the synced RTC via `Date.now()`.

## Wi-Fi won't connect
The ESP32 is **2.4 GHz only** — it cannot join 5 GHz networks. Connect to the
2.4 GHz SSID. See [04-using-bruce.md](04-using-bruce.md) §3.

## Boot loop / blank screen after flashing
Usually a wrong/corrupt image. Reflash the correct StickC Plus2 build
([03-flashing-bruce.md](03-flashing-bruce.md)). The device isn't bricked — a clean
reflash fixes it.
