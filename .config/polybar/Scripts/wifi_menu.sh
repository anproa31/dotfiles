#!/usr/bin/env bash

# Rofi WiFi menu via nmcli: scan, toggle radio, connect (asks password if secured).

notify() { command -v notify-send >/dev/null 2>&1 && notify-send "WiFi" "$1"; }

state=$(nmcli -t -f WIFI radio | head -1)   # enabled / disabled
if [ "$state" = "enabled" ]; then
    toggle="󰖪  Turn WiFi off"
else
    toggle="󰖩  Turn WiFi on"
fi

nmcli dev wifi rescan >/dev/null 2>&1
list=$(nmcli --fields SIGNAL,SSID --terse dev wifi list | sort -t: -k1 -nr \
       | awk -F: '$2!="" && !seen[$2]++ {printf "%s%%  %s\n", $1, $2}')

chosen=$(printf "%s\n%s\n" "$toggle" "$list" | rofi -dmenu -i -p "WiFi")
[ -z "$chosen" ] && exit 0

case "$chosen" in
    *"Turn WiFi off") nmcli radio wifi off; exit ;;
    *"Turn WiFi on")  nmcli radio wifi on;  exit ;;
esac

# strip leading "NN%  " to recover SSID (keeps spaces in SSID)
ssid=$(printf '%s' "$chosen" | sed 's/^[0-9]*%  //')

# already-known connection -> just bring it up
if nmcli -t -f NAME connection show | grep -qxF "$ssid"; then
    nmcli connection up id "$ssid" && notify "Connected: $ssid" || notify "Failed: $ssid"
    exit
fi

# open vs secured
sec=$(nmcli -t -f SSID,SECURITY dev wifi list | awk -F: -v s="$ssid" '$1==s{print $2; exit}')
if [ -z "$sec" ] || [ "$sec" = "--" ]; then
    nmcli dev wifi connect "$ssid" && notify "Connected: $ssid" || notify "Failed: $ssid"
else
    pass=$(rofi -dmenu -password -p "Password: $ssid")
    [ -z "$pass" ] && exit 0
    nmcli dev wifi connect "$ssid" password "$pass" && notify "Connected: $ssid" || notify "Failed: $ssid"
fi
