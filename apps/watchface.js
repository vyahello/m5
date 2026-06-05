// watchface.js — battery + clock watchface for M5StickC Plus2 (Bruce v1.15, ES5)
// Reads the live RTC via Date.now() (epoch ms). After you NTP-sync the clock
// (Config -> Clock -> Via NTP Set Timezone), this shows the real time and date,
// survives re-launches, and self-corrects. Loops until any button is pressed.
//
// NOTE: this build supports Date.now() only (not new Date()). Bruce stores LOCAL
// time in the system clock, so no extra timezone math is needed. If the time is
// off by a whole number of hours, set TZ_FIX_HOURS below to correct it.
var TZ_FIX_HOURS = 0;

var display  = require('display');
var device   = require('device');
var keyboard = require('keyboard');

var W = display.width();
var H = display.height();
function C(r, g, b) { return display.color(r, g, b); }
var BLACK=C(0,0,0), WHITE=C(255,255,255), GREEN=C(0,255,0), CYAN=C(0,200,255),
    YELLOW=C(255,210,0), RED=C(255,40,40), PURPLE=C(150,20,210);

var DOW = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
var MON = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

function p2(n) { return (n < 10 ? "0" : "") + n; }

// Convert days-since-1970 to [year, month, day] (Hinnant civil_from_days).
function ymd(z) {
    z += 719468;
    var era = Math.floor((z >= 0 ? z : z - 146096) / 146097);
    var doe = z - era * 146097;
    var yoe = Math.floor((doe - Math.floor(doe/1460) + Math.floor(doe/36524) - Math.floor(doe/146096)) / 365);
    var y = yoe + era * 400;
    var doy = doe - (365 * yoe + Math.floor(yoe/4) - Math.floor(yoe/100));
    var mp = Math.floor((5 * doy + 2) / 153);
    var d = doy - Math.floor((153 * mp + 2) / 5) + 1;
    var m = mp < 10 ? mp + 3 : mp - 9;
    return [m <= 2 ? y + 1 : y, m, d];
}

function batColor(p) { return p > 50 ? GREEN : (p > 20 ? YELLOW : RED); }

// static frame
display.fill(BLACK);
display.drawRect(2, 2, W - 4, H - 4, PURPLE);

var lastTime = "", lastDate = "", lastPct = -1;

function drawDate(str) {
    display.drawFillRect(4, 8, W - 8, 16, BLACK);
    display.setTextSize(1);
    display.setTextColor(CYAN);
    var x = (W - str.length * 6) / 2; if (x < 0) x = 0;
    display.drawString(str, x, 12);
}
function drawClock(str) {
    display.drawFillRect(4, 38, W - 8, 30, BLACK);
    display.setTextSize(3);
    display.setTextColor(GREEN);
    var x = (W - str.length * 18) / 2; if (x < 0) x = 0;
    display.drawString(str, x, 40);
}
function drawBattery(p) {
    display.drawFillRect(4, 92, W - 8, H - 96, BLACK);
    var bx = 46, by = 98, bw = 100, bh = 26;
    display.drawRect(bx, by, bw, bh, WHITE);
    display.drawFillRect(bx + bw, by + 7, 6, 12, WHITE);
    var fw = Math.floor((bw - 6) * p / 100);
    display.drawFillRect(bx + 3, by + 3, fw, bh - 6, batColor(p));
    display.setTextSize(2);
    display.setTextColor(WHITE);
    display.drawString(p2(p) + "%", bx + bw + 14, by + 5);
}

for (var i = 0; i < 3600; i++) {
    if (keyboard.getAnyPress()) break;            // any button exits

    var totalSec = Math.floor(Date.now() / 1000) + TZ_FIX_HOURS * 3600;
    var days = Math.floor(totalSec / 86400);
    var t = totalSec - days * 86400;
    var hh = Math.floor(t / 3600), mm = Math.floor((t % 3600) / 60), ss = t % 60;
    var tstr = p2(hh) + ":" + p2(mm) + ":" + p2(ss);

    var c = ymd(days);
    var wd = DOW[((days % 7) + 4 + 7) % 7];
    var dstr = wd + " " + p2(c[2]) + " " + MON[c[1] - 1] + " " + c[0];

    if (dstr !== lastDate) { drawDate(dstr); lastDate = dstr; }
    if (tstr !== lastTime) { drawClock(tstr); lastTime = tstr; }
    var pct = device.getBatteryCharge();
    if (pct !== lastPct) { drawBattery(pct); lastPct = pct; }

    delay(150);
}

display.fill(BLACK);
display.setTextSize(2);
display.setTextColor(CYAN);
display.drawString("Watchface off", 30, 55);
delay(1200);
