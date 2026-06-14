#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME="yotsugi"
SRC="$SCRIPT_DIR/themes/$THEME"
DEST="/usr/share/sddm/themes/$THEME"
CONF="/etc/sddm.conf.d/theme.conf"

[ -d "$SRC" ] || {
  echo "Theme not found: $SRC" >&2
  exit 1
}
command -v sddm >/dev/null 2>&1 || {
  echo "sddm is not installed." >&2
  exit 1
}

echo ":: Installing $THEME -> $DEST"
sudo rm -rf "$DEST"
sudo mkdir -p /usr/share/sddm/themes
sudo cp -r "$SRC" "$DEST"

echo ":: Setting $THEME as the active theme"
sudo mkdir -p /etc/sddm.conf.d
printf '[Theme]\nCurrent=%s\n' "$THEME" | sudo tee "$CONF" >/dev/null

echo ":: Done."
echo "   Preview : sddm-greeter-qt6 --test-mode --theme $DEST"
echo "   Apply   : reboot, or 'sudo systemctl restart sddm' (logs you out)"
