// demo.js — animated info + demo for M5StickC Plus2 on Bruce v1.15
// Pure ES5. Uses only the verified display API (no println/fill-by-int surprises).
// Output is on the device TFT. A clean run prints nothing to serial (errors only).

var display = require('display');
var device  = require('device');

var W = display.width();
var H = display.height();

function C(r, g, b) { return display.color(r, g, b); }
var BLACK  = C(0, 0, 0);
var WHITE  = C(255, 255, 255);
var GREEN  = C(0, 255, 0);
var CYAN   = C(0, 200, 255);
var PURPLE = C(150, 20, 210);

function clear() { display.fill(BLACK); }

// Center text horizontally (GFX default font ~6px/char at size 1).
function centerText(txt, y, size, col) {
    display.setTextSize(size);
    display.setTextColor(col);
    var x = (W - txt.length * 6 * size) / 2;
    if (x < 0) x = 0;
    display.drawString(txt, x, y);
}

// 1) Color-cycling intro splash
function intro() {
    var cols = [C(255, 0, 0), C(255, 150, 0), GREEN, CYAN, PURPLE];
    for (var i = 0; i < cols.length; i++) {
        clear();
        display.drawRect(2, 2, W - 4, H - 4, cols[i]);
        centerText("M5StickC", 30, 2, cols[i]);
        centerText("Plus2", 55, 2, WHITE);
        centerText("Bruce JS Demo", 90, 1, CYAN);
        delay(220);
    }
    delay(350);
}

// 2) Device info panel
function infoPanel() {
    clear();
    display.drawRect(2, 2, W - 4, H - 4, PURPLE);
    display.setTextSize(2);
    display.setTextColor(GREEN);
    display.drawString("Device Info", 10, 8);
    display.setTextSize(1);
    display.setTextColor(WHITE);
    display.drawString("Board  : " + device.getBoard(), 10, 35);
    display.drawString("Screen : " + W + " x " + H, 10, 50);
    display.drawString("Battery: " + device.getBatteryCharge() + " %", 10, 65);
    display.drawString("Engine : Bruce JS (ES5)", 10, 80);
    display.drawString("Storage: 8MB flash / 3MB FS", 10, 95);
    delay(2600);
}

// 3) Animated loading bar
function loadingBar() {
    clear();
    display.drawRect(2, 2, W - 4, H - 4, CYAN);
    centerText("Initializing...", 18, 1, WHITE);
    var bx = 20, by = 58, bw = W - 40, bh = 22;
    display.drawRect(bx, by, bw, bh, WHITE);
    for (var p = 0; p <= 100; p += 4) {
        var fw = ((bw - 4) * p) / 100;
        display.drawFillRect(bx + 2, by + 2, fw, bh - 4, C(p * 2, 255 - p * 2, 60));
        display.drawFillRect(bx, by + bh + 8, bw, 10, BLACK);
        centerText(p + " %", by + bh + 8, 1, WHITE);
        delay(38);
    }
    delay(400);
}

// 4) Bouncing block (erase-then-draw, no flicker)
function bounce() {
    clear();
    display.drawRect(2, 2, W - 4, H - 4, PURPLE);
    centerText("Bouncing Bruce", 8, 1, WHITE);
    var s = 14, x = 20, y = 24, vx = 5, vy = 4, px = x, py = y;
    var cols = [C(255, 0, 0), GREEN, C(0, 150, 255), C(255, 255, 0)];
    for (var f = 0; f < 130; f++) {
        display.drawFillRect(px, py, s, s, BLACK);   // erase old
        x += vx; y += vy;
        if (x <= 4 || x >= W - 4 - s) vx = -vx;
        if (y <= 22 || y >= H - 4 - s) vy = -vy;
        display.drawFillRect(x, y, s, s, cols[f % cols.length]);
        px = x; py = y;
        delay(25);
    }
}

// ---- run ----
intro();
infoPanel();
loadingBar();
bounce();

// outro
clear();
display.drawRect(2, 2, W - 4, H - 4, GREEN);
centerText("Demo complete!", 45, 2, GREEN);
centerText("Bruce JS on M5StickC+2", 85, 1, CYAN);
delay(3000);
