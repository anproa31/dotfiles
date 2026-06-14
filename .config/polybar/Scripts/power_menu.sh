#!/usr/bin/env bash

# Rofi power menu. Triggered by clicking the left name module in polybar.

confirm() {
    [ "$(printf 'No\nYes\n' | rofi -dmenu -i -p "$1?")" = "Yes" ]
}

chosen=$(printf "󰐥  Shutdown\n󰜉  Reboot\n󰒲  Suspend\n󰍃  Logout\n" \
    | rofi -dmenu -i -p "Power")

case "$chosen" in
    *Shutdown) confirm "Shutdown" && systemctl poweroff ;;
    *Reboot)   confirm "Reboot"   && systemctl reboot ;;
    *Suspend)  systemctl suspend ;;
    *Logout)   confirm "Logout"   && bspc quit ;;
esac
