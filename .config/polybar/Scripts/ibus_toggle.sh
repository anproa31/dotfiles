#!/bin/sh

# Toggle / display ibus input engine for polybar.
# No arg  -> print current language label (for the module).
# "toggle" -> switch between English (xkb:us::eng) and Vietnamese (Bamboo).

EN_ENGINE="xkb:us::eng"
VN_ENGINE="Bamboo"

current=$(ibus engine 2>/dev/null)

case "$1" in
    toggle)
        if [ "$current" = "$VN_ENGINE" ]; then
            ibus engine "$EN_ENGINE"
        else
            ibus engine "$VN_ENGINE"
        fi
        ;;
    *)
        if [ "$current" = "$VN_ENGINE" ]; then
            echo "VN"
        else
            echo "EN"
        fi
        ;;
esac
