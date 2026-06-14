#!/bin/sh

ethernet_dev=$(nmcli -t -f DEVICE,TYPE,STATE dev | awk -F: '$2=="ethernet" && $3=="connected" {print $1; exit}')

if [ -n "$ethernet_dev" ]; then
    echo "󰈀 $ethernet_dev"
    exit
fi

if [ "$(nmcli -t -f WIFI radio 2>/dev/null | head -1)" = "disabled" ]; then
    echo "󰖪 off"
    exit
fi

ssid=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '/^yes/{print $2; exit}')

if [ -n "$ssid" ]; then
    echo "$ssid"
else
    echo "󰖩 ----"
fi
