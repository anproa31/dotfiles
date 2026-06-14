#!/bin/bash
# ============================================================================
# Minecraft GRUB theme installer (minegrub by Lxtharia)
#
# Clones the theme repo and installs it end-to-end:
#   - python-pillow (needed by the splash auto-update service)
#   - copies the theme into /boot/grub/themes/minegrub
#   - sets GRUB_THEME in /etc/default/grub (backs up the original first)
#   - installs + enables the minegrub-update systemd service
#   - regenerates /boot/grub/grub.cfg
#
# Usage:  sudo bash install.sh
# ============================================================================
set -e

REPO_URL="https://github.com/Lxtharia/minegrub-theme.git"
SRC="/tmp/minegrub-theme"
GRUB_DIR="/boot/grub"
THEME_DIR="$GRUB_DIR/themes/minegrub"

if [[ $EUID -ne 0 ]]; then echo "Must be run as root (use: sudo bash install.sh)."; exit 1; fi

echo "==> [1/6] Cloning the minegrub theme repo into $SRC"
rm -rf "$SRC"
git clone --depth 1 "$REPO_URL" "$SRC"

if [[ ! -d "$SRC/minegrub" ]]; then echo "Theme source $SRC/minegrub not found after clone."; exit 1; fi

echo "==> [2/6] Installing python-pillow (needed by the splash auto-update service)"
pacman -S --needed --noconfirm python-pillow

echo "==> [3/6] Copying theme to $THEME_DIR"
mkdir -p "$GRUB_DIR/themes"
cp -ruv "$SRC/minegrub" "$GRUB_DIR/themes/" | awk '$0 !~ /skipped/ { print "\t"$0 }'

echo "==> [4/6] Setting GRUB_THEME in /etc/default/grub"
cp -n /etc/default/grub /etc/default/grub.bak.minegrub || true
if grep -q '^GRUB_THEME=' /etc/default/grub; then
    sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"$THEME_DIR/theme.txt\"|" /etc/default/grub
else
    echo "GRUB_THEME=\"$THEME_DIR/theme.txt\"" >> /etc/default/grub
fi
grep '^GRUB_THEME=' /etc/default/grub

echo "==> [5/6] Installing + enabling the splash auto-update systemd service"
cp -uv "$SRC/minegrub-update.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable minegrub-update.service
# Pre-render the first splash so the menu isn't blank on first boot
/usr/bin/python3 "$THEME_DIR/update_theme.py" || echo "  (splash pre-render skipped; will run on next boot)"

echo "==> [6/6] Regenerating /boot/grub/grub.cfg"
grub-mkconfig -o "$GRUB_DIR/grub.cfg"

echo
echo "======= Done! ======="
echo "Reboot to see the Minecraft GRUB theme."
echo "Backup of original grub defaults: /etc/default/grub.bak.minegrub"
