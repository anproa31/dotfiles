#!/bin/sh

# Polybar label: bluetooth power state + connected device.

power=$(bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2; exit}')

if [ "$power" != "yes" ]; then
    echo "󰂲"
    exit
fi

dev=$(bluetoothctl info 2>/dev/null | awk -F': ' '/Name:/{print $2; exit}')

if [ -n "$dev" ]; then
    echo "󰂱 $dev"
else
    echo "󰂯"
fi
