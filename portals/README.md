# Evil Portal templates

Captive-portal HTML pages for Bruce's **Evil Portal** (and the portal stage of
Karma / Clone attacks) on the M5StickC Plus2.

> ⚠️ **Authorized engagements only.** These pages impersonate login screens to
> harvest credentials. Use them solely on networks/people you are **explicitly
> authorized** (signed scope) to test. See [docs/06-pentesting.md](../docs/06-pentesting.md).

## What's here

Verified to capture on Bruce v1.15 (form posts trigger `credsController`).

| File | Mimics | Captures (`name=`) | Form action |
|------|--------|--------------------|-------------|
| `tp-link.html` | TP-Link router login | `password` | `/post` |
| `xiaomi.html` | Xiaomi/Mi router | `password` | `/post` |
| `asus.html` | ASUS router | `password` | `/post` |
| `huawei.html` | Huawei router | `password` | `/post` |
| `tenda.html` | Tenda router | `password` | `/post` |
| `mikrotik.html` | MikroTik router | `password` | `/post` |
| `keenetic.html` | Keenetic router | `password` | `/post` |
| `netis.html` | Netis router | `password` | `/post` |
| `mercusys.html` | Mercusys router | `password` | `/post` |
| `google.html` | Google sign-in | `email`, `password` | `/get` |
| `facebook.html` | Facebook login | `email`, `password` | `/get` |
| `appleid.html` | Apple ID | `email`, `password`, `remember` | `/get` |
| `t-mobile.html` | T-Mobile Wi-Fi | `email`, `password` | `/get` |

Router pages (the `password`-only "firmware update / re-enter Wi-Fi password"
style) pair best with a **cloned SSID + deauth** — victims kicked off the real AP
re-enter the *Wi-Fi* password into your lookalike. The brand pages suit
open-guest-network credential phishing.

## How Bruce captures (verified from source)

Bruce's web server registers `webServer.on("/post", credsController)` **and** an
`onNotFound` handler that calls `credsController` for **any** request carrying form
args. So both `action="/post"` and `action="/get"` templates work — every submitted
field is logged as `key: value`. A field literally named `password` gets special
handling (masking / verify mode per Config).

- **Captured creds** are written to `<template-name>_creds.csv` (Evil Portal creds
  dir). Pull them off with the Web UI file manager or
  `./tools/bruce-cmd.sh "storage read /..._creds.csv"`.
- **Auto-name the rogue AP:** the template's **first line** `<!-- AP="Free_WiFi" -->`
  makes Bruce set the AP SSID to `Free_WiFi` automatically. The
  `tools/portals-set-ap.sh` script writes/updates that line for you (below).

## Deploy to the device

Templates upload to `/PortalTemplates/` (any folder works — Bruce's "Custom Html"
picker browses from `/`).

**Easiest — set the AP name and push all pages at once:**

```bash
./tools/portals-set-ap.sh Test_AP            # bake AP="Test_AP" into every page + upload
./tools/portals-set-ap.sh Coffee portals/google.html   # one page, custom SSID
./tools/portals-set-ap.sh --clear            # remove the baked AP name (Bruce default / asks on-device)
PUSH=0 ./tools/portals-set-ap.sh Test_AP     # edit local only, don't upload
```

**Manual — upload as-is with `bruce-put.sh`:**

```bash
./tools/bruce-put.sh portals/tp-link.html /PortalTemplates/tp-link.html   # one file
for f in portals/*.html; do ./tools/bruce-put.sh "$f" "/PortalTemplates/$(basename "$f")"; done
```

Then on the device: **WiFi → WiFi Atks → Evil Portal → Custom Html** → pick the
file → confirm the AP name → run. (For Karma/Clone, the same Custom Html page
backs the portal stage.) Full attack chain: [docs/06-pentesting.md §3.6](../docs/06-pentesting.md#36-chained-playbook--deauth--karma--evil-portal).

> 3 MB LittleFS — all 13 pages total ~75 KB, no space concern. Prune captured
> `*_creds.csv` between engagements (`./tools/bruce-rm.sh`).

## Customizing

Edit the HTML freely — keep a `<form>` whose inputs have `name="..."` attributes
(those names become the CSV columns). Tailor a page to the client's real login for
a realistic assessment, and add the `<!-- AP="..." -->` first line to match their
SSID naming.

## Sources

- [Batcherss/evil-portal-html](https://github.com/Batcherss/evil-portal-html) — router clones (Bruce `/post` format)
- [Borys-esp/EvilPortal_DB](https://github.com/Borys-esp/EvilPortal_DB) — brand pages
