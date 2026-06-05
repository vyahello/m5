// hello.js — Bruce JavaScript (ES5) hello-world for M5StickC Plus2.
// Draws to the device screen using the verified v1.15 display API.
var display = require('display');
var device = require('device');

var w = display.width();
var h = display.height();

display.drawFillRect(0, 0, w, h, display.color(0, 0, 0)); // clear to black
display.setTextSize(2);
display.setTextColor(display.color(0, 255, 0));           // green
display.drawString("Hello World!", 8, 20);
display.setTextSize(1);
display.setTextColor(display.color(255, 255, 255));       // white
display.drawString("Bruce JS on " + device.getBoard(), 8, 50);
display.drawString("Battery: " + device.getBatteryCharge() + "%", 8, 65);
display.drawRect(3, 3, w - 6, h - 6, display.color(150, 20, 210));

delay(6000); // hold it on screen for 6s
