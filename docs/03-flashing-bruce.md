# 3. Flashing Bruce

This device runs **Bruce v1.15** (`firmware/Bruce-m5stack-cplus2.bin`). This page
covers (re)flashing it with esptool. For *using* Bruce, see
[04-using-bruce.md](04-using-bruce.md).

> ⚠️ **Authorized use only.** Bruce's Wi-Fi/BLE/IR features are for testing
> networks and devices you own or are explicitly authorized to test.

All commands run from the repo root with the venv active:

```bash
cd /home/kali/m5 && source venv/bin/activate
PORT=/dev/ttyACM0
```

## Identify the chip (sanity check)

```bash
esptool --port $PORT flash-id      # -> ESP32-PICO-V3-02, 8MB
```

## The firmware file

`firmware/Bruce-m5stack-cplus2.bin` — the Bruce **StickC Plus2** build (Bruce 1.15,
from <https://github.com/BruceDevices/firmware/releases>). It's a **merged image**
flashed at offset **`0x0`** (bootloader magic `e9` sits at `0x1000`; the first
4 KB are `0xFF` padding — that's normal).

> Get the right file for this board: **`Bruce-m5stack-cplus2.bin`** (cplus2 =
> StickC **Plus2**). Not `cplus1_1` (older StickC Plus) or `sticks3` (ESP32-S3).

## Flash it

```bash
./tools/free-port.sh                 # release the port first
source venv/bin/activate
esptool --port $PORT erase-flash
esptool --port $PORT --baud 921600 write-flash 0x0 firmware/Bruce-m5stack-cplus2.bin
```

The device reboots into Bruce (logo + main menu). Verify:

```bash
./tools/bruce-cmd.sh info            # -> Bruce v1.15 ... Device: M5StickC Plus2
```

## Partition layout (after flashing Bruce)

| Label | Type | Offset | Size |
|-------|------|--------|------|
| nvs | data | `0x9000` | 24 K |
| app0 | app | `0x10000` | ~4.9 MB (Bruce) |
| spiffs (LittleFS) | data | `0x4f0000` | **3 MB** (user storage: `/scripts`, configs, captures) |
| coredump | data | `0x7f0000` | 64 K |

→ **~3 MB of usable on-device storage** (no SD card installed).

## Backups / restore

Two images live in `firmware/`:

| File | What it is | Use for |
|------|------------|---------|
| `Bruce-m5stack-cplus2.bin` | clean Bruce 1.15 **app** image (~3.6 MB) | a fresh Bruce flash |
| `m5-bruce-full-8MB-20260606.bin` | **full 8 MB snapshot** of the configured device — includes NVS/settings, Wi-Fi config, and the LittleFS `/scripts` (apps, games, captures) | exact restore point |

> The full snapshot was taken **2026-06-06**
> (sha256 `eb9feeb1e03153b41028012a278ed209890eadb0e51712338bbd273532458b9d`).

### Restore the exact configured device (recommended)

```bash
./tools/free-port.sh && source venv/bin/activate
esptool --port $PORT --baud 921600 write-flash 0x0 firmware/m5-bruce-full-8MB-20260606.bin
```

### Make a fresh full backup (e.g. after changing settings/scripts)

```bash
./tools/free-port.sh && source venv/bin/activate
esptool --port $PORT --baud 921600 read-flash 0x0 0x800000 firmware/m5-bruce-full-8MB-$(date +%Y%m%d).bin
```

> ⚠️ **No backup of the original M5 factory firmware exists** (Bruce was flashed
> over it without one). To return to the factory demo you'd need an official M5
> image (e.g. via **M5Burner**) — these backups restore *Bruce*, not the factory.

> 💡 These `.bin` files are large; if this workspace becomes a git repo, add
> `firmware/*.bin` to `.gitignore`.

## Gotchas

- **"busy" / connect fails:** a serial monitor is open → `./tools/free-port.sh`.
- **Slow flashing:** keep `--baud 921600` (drop to `115200` only if it errors).
- **Wrong-board build:** a non-Plus2 image boots to a blank/garbled screen —
  reflash `Bruce-m5stack-cplus2.bin`. A half-flash is never bricked; just reflash.

➡️ Next: [4. Using Bruce](04-using-bruce.md)
