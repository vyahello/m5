# 1. The device

## What it is

An **M5StickC Plus2** (M5Stack) — a tiny battery-powered gadget built around an
**Espressif ESP32**. It has a colour screen, three buttons, an IMU, a buzzer, an
IR transmitter, Wi-Fi and Bluetooth. It is **not** a Linux computer; it runs a
single **firmware** image. In this workspace that firmware is **[Bruce](https://github.com/pr3y/Bruce)**
(a pentest/multitool firmware) — see [03-flashing-bruce.md](03-flashing-bruce.md)
and [04-using-bruce.md](04-using-bruce.md).

## This unit (probed with esptool)

| Property | Value |
|----------|-------|
| Chip | **ESP32-PICO-V3-02** (rev v3.1), dual-core Xtensa LX6 @ 240 MHz |
| Flash | **8 MB** (embedded) |
| PSRAM | 2 MB (embedded) |
| Radios | Wi-Fi b/g/n (**2.4 GHz only**) + BT Classic + BLE |
| MAC | `c0:cd:d6:14:9f:3c` |
| USB-serial bridge | WCH **CH9102** (`1a86:55d4`) → enumerates as **`/dev/ttyACM0`** (CDC-ACM) |
| Stable port path | `/dev/serial/by-id/usb-1a86_USB_Single_Serial_5B1E047086-if00` |

## Peripherals

| Component | Detail |
|-----------|--------|
| Display | 1.14" TFT, ST7789V2, 135×240 (landscape 240×135 in Bruce) |
| IMU | 6-axis MPU6886 (accel + gyro) |
| RTC | BM8563 (set via NTP — see [04-using-bruce.md](04-using-bruce.md)) |
| Buzzer | passive buzzer (**no speaker/DAC** → `tone`/`beep` only, no TTS/audio files) |
| IR | on-board infrared transmitter |
| LED | single **red** LED (no RGB) |
| Mic | SPM1423 PDM mic |
| Battery | ~200 mAh LiPo, USB-C charging |
| Buttons | 3 — see button map in [04-using-bruce.md](04-using-bruce.md) |
| Expansion | Grove (I²C) port + 8-pin header (HAT) — no built-in SD slot |

## Buttons (verified from the Bruce StickC Plus2 build)

`SEL_BTN=37, UP_BTN=35, DW_BTN=39`:

| Physical button | GPIO | Bruce action |
|-----------------|------|--------------|
| Big round **"M5" button (front)** | 37 | **Select / Enter** |
| **Top button, right side** | 39 | **Next** (move selection) |
| **Power button, lower-left side** | 35 | **Back/Esc** (tap); **hold ~6 s = power off** |

## Power note

On battery the Plus2 stays on only while its power-hold line is asserted — Bruce
handles this, so it runs standalone after you unplug USB. USB is needed only for
**flashing, serial CLI, and charging**.

➡️ Next: [2. Connecting](02-connecting.md)
