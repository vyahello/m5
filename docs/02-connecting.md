# 2. Connecting (USB & serial)

Everything here runs from the repo root, `/home/kali/m5`.

## Detect the device

Plug the USB-C cable into the bottom of the device, then:

```bash
lsusb | grep -i 1a86          # -> ID 1a86:55d4 QinHeng ... USB Single Serial
ls -l /dev/ttyACM0            # crw-rw---- root dialout ... /dev/ttyACM0
```

> The CH9102 bridge enumerates as **CDC-ACM → `/dev/ttyACM0`** (not `ttyUSB`).
> If it ever moves to `ttyACM1`, use the stable path:
> `/dev/serial/by-id/usb-1a86_USB_Single_Serial_5B1E047086-if00`.

## Permissions (already set on this machine)

`/dev/ttyACM0` is `root:dialout` (660) and user `kali` is in the **`dialout`**
group, so serial works **without sudo**. Do **not** use sudo with esptool — it
breaks the venv Python path. (Fresh user: `sudo usermod -aG dialout "$USER"`, then
re-login.)

## Python tooling

A virtualenv at `venv/` holds **esptool v5.3.0** and **pyserial**:

```bash
source venv/bin/activate       # for esptool commands
```

The helper scripts in `tools/` call the venv automatically — you don't need to
activate it just to use them.

## Talk to the device

Once Bruce is flashed (see [03-flashing-bruce.md](03-flashing-bruce.md)), the
device speaks a serial command CLI at **115200 8N1**:

```bash
./tools/bruce-cmd.sh info        # one-shot command + reply
./tools/bruce-shell.sh           # interactive live console (exit: Ctrl-])
```

Or a raw serial monitor:

```bash
./tools/free-port.sh
screen /dev/ttyACM0 115200       # exit: Ctrl-A then K then Y
```

## The one rule: one owner of the port

Only **one** program can hold `/dev/ttyACM0` at a time. A serial monitor (or a
detached `screen`) blocks esptool and the helper scripts with "busy"/no reply.
Free it with:

```bash
./tools/free-port.sh
```

A *looping script/game on the device* also blocks the serial CLI — press a button
on the device to exit it. See [05-troubleshooting.md](05-troubleshooting.md).

➡️ Next: [3. Flashing Bruce](03-flashing-bruce.md)
