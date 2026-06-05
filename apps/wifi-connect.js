// wifi-connect.js — join a Wi-Fi network on Bruce (M5StickC Plus2, ES5).
// EDIT the two lines below, then deploy + run:
//   ./bruce-put.sh wifi-connect.js /scripts/wifi-connect.js
//   ./bruce-cmd.sh "js /scripts/wifi-connect.js"
// NOTE: ESP32 is 2.4 GHz only — use your router's 2.4 GHz SSID (not 5 GHz).

var SSID = "YOUR_WIFI_NAME";       // <-- your 2.4 GHz network name
var PASS = "YOUR_WIFI_PASSWORD";   // <-- your Wi-Fi password

var wifi    = require('wifi');
var display = require('display');

function show(msg, col) {
    display.fill(display.color(0, 0, 0));
    display.setTextSize(1);
    display.setTextColor(col);
    display.drawString(msg, 8, 30);
}

show("Connecting to " + SSID + " ...", display.color(0, 200, 255));
wifi.connect(SSID, 15, PASS);      // (ssid, timeout_seconds, password)

if (wifi.connected()) {
    show("Wi-Fi CONNECTED", display.color(0, 255, 0));
    display.drawString(SSID, 8, 50);
} else {
    show("Wi-Fi FAILED", display.color(255, 40, 40));
    display.drawString("Check 2.4GHz SSID + pass", 8, 50);
}
delay(4000);
