#!/usr/bin/env bash

# Rofi Bluetooth menu via bluetoothctl: power, scan, pair/connect/disconnect.

notify() { command -v notify-send >/dev/null 2>&1 && notify-send "Bluetooth" "$1"; }

power=$(bluetoothctl show | awk '/Powered:/{print $2; exit}')

# powered off -> only offer power on
if [ "$power" != "yes" ]; then
    chosen=$(printf "󰂯  Power on\n" | rofi -dmenu -i -p "Bluetooth (off)")
    [ "$chosen" = "󰂯  Power on" ] && bluetoothctl power on && notify "Powered on"
    exit
fi

# short background scan so new devices show up
bluetoothctl --timeout 6 scan on >/dev/null 2>&1 &

# devices: "Device MAC Name" -> "MAC Name"
devices=$(bluetoothctl devices | cut -d' ' -f2-)

chosen=$(printf "󰂲  Power off\n󰂰  Scan (6s)\n%s\n" "$devices" | rofi -dmenu -i -p "Bluetooth")
[ -z "$chosen" ] && exit 0

case "$chosen" in
    "󰂲  Power off") bluetoothctl power off; notify "Powered off"; exit ;;
    "󰂰  Scan (6s)") bluetoothctl --timeout 6 scan on >/dev/null 2>&1; exit ;;
esac

mac=$(printf '%s' "$chosen" | awk '{print $1}')
name=$(printf '%s' "$chosen" | cut -d' ' -f2-)

if bluetoothctl info "$mac" | grep -q "Connected: yes"; then
    bluetoothctl disconnect "$mac" && notify "Disconnected: $name"
else
    bluetoothctl pair "$mac" >/dev/null 2>&1
    bluetoothctl trust "$mac" >/dev/null 2>&1
    bluetoothctl connect "$mac" && notify "Connected: $name" || notify "Failed: $name"
fi
