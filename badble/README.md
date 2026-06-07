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

## The payloads

| File | Target | Precondition (have this on screen, unlocked) | Does |
|------|--------|----------------------------------------------|------|
| `proof-typing.txt` | iOS + Android | any text field focused (Notes) | types one labelled proof line |
| `notes-demo.txt` | iOS + Android | a new note, cursor blinking | types a 3-line authorized-test notice |
| `ios-safari-url.txt` | iPhone/iPad | Safari open, address bar tapped | navigates to `example.com` |
| `ios-spotlight.txt` | iPadOS (best) / newer iPhone | Home Screen | Cmd+Space → Spotlight → search `weather` |
| `android-browser-url.txt` | Android | Chrome open, omnibox tapped | navigates to `example.com` |
| `android-search.txt` | Android | Google search/launcher field focused | types & submits a harmless query |

All are plain duckyscript (`REM` comments, `DELAY` ms, `STRING`, `ENTER`,
`GUI`=Cmd). Edit the `STRING` lines freely — e.g. point a URL payload at a page on
**your own** machine (`http://192.168.1.50/test`).

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
3. On the target phone: **Settings → Bluetooth**, find the keyboard, **pair** it
   (accept the prompt). Make sure the phone is **unlocked** with the required app /
   field focused (see the table).
4. Bruce types the script. Watch the field on the phone.

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
