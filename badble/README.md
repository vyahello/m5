# Bad-BLE payloads (HID keyboard injection)

Benign, lab-safe **Ducky-style** scripts for Bruce's **Bad BLE** feature — the
M5StickC Plus2 advertises as a Bluetooth keyboard and "types" these once a target
**pairs** with it.

> ⚠️ **Authorized, local-lab use only.** Run these solely against **your own**
> iPhones / Android devices (or devices you have explicit written permission to
> test). These payloads are intentionally **non-destructive** — they prove keystroke
> injection and pairing/lock behavior, nothing more.

## Reality check — phones are not PCs

Bad-BLE against a phone is much more limited than USB BadUSB against a laptop:

- **Pairing is required.** The target shows a Bluetooth pairing prompt you **cannot
  skip** — someone must accept it (a valid thing to test: will a user tap "pair"?).
- **The phone must be UNLOCKED.** A locked iPhone/Android **ignores** HID input —
  there's no lock-screen bypass here. Confirming "locked = no injection" is itself a
  finding worth recording.
- **No "run box."** Phones have no Win+R / Spotlight-exec equivalent for arbitrary
  commands, so payloads type into a **focused field** (Notes, an address bar, search).
- **US keyboard layout** is assumed by the typed `STRING`s.

So these scripts demonstrate *injection into whatever field is focused* and let you
test the pairing/lock posture of your devices — not silent remote code execution.

## Platform support (verified on this unit)

The M5StickC Plus2 is a **classic ESP32 (BLE 4.2)**, and that determines who pairs:

| Platform | Bad-BLE / BLE-keyboard HID | Why |
|----------|----------------------------|-----|
| **Android** | ✅ pairs & types | lenient about BLE-HID peripherals |
| **Windows / Linux** | ✅ usually | accept standard BLE-HID |
| **iPhone / iPad** | ❌ won't enumerate it | iOS is strict about BLE-HID bonding/appearance; the ESP32 HID stack doesn't satisfy it |

Verified here: the stick advertises as **`Keyboard_xxxxx`** — **Android sees and pairs
it; iPhones never list it.** This is a known classic-ESP32 + iOS limitation, fixable
only in firmware (you'd need an **ESP32-S3** or **nRF52840** board for iOS HID). It's
itself a reportable finding: *iOS resists the rogue BLE-HID keyboard; Android doesn't.*

> **Why BLE spam still works on iPhones but the keyboard doesn't:** spam is
> **advertising** (connectionless broadcast — iOS just *hears* a packet and pops a
> dialog), whereas the keyboard needs a **bonded, encrypted HID connection** that iOS
> gates strictly. Advert-based BLE (spam, beacons, SourApple) → works on iOS;
> connection/HID-based BLE (Bad-BLE) → Android only on this chip.

**Bottom line: do your Bad-BLE testing on Android.**

## The payloads

All are plain duckyscript (`REM` comments, `DELAY` ms, `STRING`, `ENTER`, `GUI`=Meta/
Cmd, `CTRL`). Edit the `STRING` lines freely — e.g. point a URL at your own box
(`http://192.168.1.50/test`).

**Field-focused** — you open the app/field, the script types into it (iOS + Android):

| File | Target | Precondition (unlocked) | Does |
|------|--------|-------------------------|------|
| `proof-typing.txt` | iOS + Android | any text field focused | types one labelled proof line |
| `notes-demo.txt` | iOS + Android | a new note, cursor blinking | types a 3-line notice |
| `ios-safari-url.txt` | iPhone/iPad | Safari open, address bar tapped | navigates to `example.com` |
| `ios-spotlight.txt` | iPadOS / newer iPhone | Home Screen | Cmd+Space → Spotlight search |
| `android-browser-url.txt` | Android | Chrome open, omnibox tapped | navigates to `example.com` |
| `android-search.txt` | Android | search field focused | submits a harmless query |

**Self-contained (Android)** — the script *opens the app itself*; only precondition is
**unlocked + on the home screen**. No taps from you:

| File | Does | Technique |
|------|------|-----------|
| `android-browser-video.txt` | opens browser + new tab, loads a URL you set (blank by default) | `GUI b` (Meta+B) → `CTRL t` → type URL |
| `android-app-launch.txt` | opens an app by name (set to Chrome) | type on home screen → launcher search → `ENTER` |
| `android-notes-write.txt` | opens Google Keep and types a note | launcher-search "Keep" → type |

> **Android shortcuts vary by OEM/launcher.** `GUI b`=open-browser and home-screen
> type-to-search work on stock/Pixel/Nova but not everywhere — if one method is dead
> on your device, use the other (Meta-key vs launcher-search). Bump the `DELAY` values
> for slow phones. These are the *robust, hands-off* payloads — but they're the most
> device-dependent, so tune per phone.

## Deploy to the device

Upload to a folder Bruce's Bad-BLE picker can browse (anything under `/` works):

```bash
# one file
./tools/bruce-put.sh badble/proof-typing.txt /BadBLE/proof-typing.txt

# all of them
for f in badble/*.txt; do ./tools/bruce-put.sh "$f" "/BadBLE/$(basename "$f")"; done
```

## Run it (on the device)

1. **BLE → Bad BLE** → pick the script (e.g. `/BadBLE/proof-typing.txt`).
2. The stick starts **advertising as a BLE keyboard**.
3. On the target phone: **Settings → Bluetooth**, find **`Keyboard_xxxxx`**, **pair**
   it (accept the prompt). Keep the phone **unlocked** and then:
   - *Field-focused scripts* → open the required app/field (see the table).
   - *Self-contained scripts* → just sit on the **home screen**; the script opens the
     app itself.
4. Bruce types the script. Watch the phone.

## Suggested test matrix (record results per device)

| Test | What you're checking | Expected secure result |
|------|----------------------|------------------------|
| Pairing prompt | does the OS ask before accepting a keyboard? | yes, explicit confirm |
| Locked injection | type while the phone is **locked** | ignored — no input lands |
| Unlocked injection | type with a field focused | input lands (proves HID works) |
| Auto-reconnect | re-advertise after first pair | OS may silently reconnect → note it |
| User awareness | would a real user notice the pairing prompt? | qualitative finding |

## Notes & safety

- **Range is short** (BLE 4.2, a few meters) — you must be close.
- Keep it **time-boxed and in your lab**; BLE HID pairing leaves traces in the
  phone's Bluetooth device list (remove it after testing).
- Want a custom payload? Edit a copy here, keep it **non-destructive**, and redeploy
  with `bruce-put.sh`. See the Bad-BLE / BLE notes in
  [../docs/06-pentesting.md §6](../docs/06-pentesting.md#6-bluetooth--ble).

## Why created, not downloaded

Public payload libraries (Hak5, assorted GitHub "ducky payload" repos) are mostly
written for **Windows/macOS/Linux** (PowerShell droppers, `Win+R` execs) — useless
or unvetted against phones, and many are deliberately destructive. The scripts here
are purpose-built for phone HID testing and reviewed to be safe for your lab.
