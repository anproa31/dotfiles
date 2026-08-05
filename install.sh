#!/usr/bin/sh
# ===========================================================================
#  Dotfiles bootstrap for a fresh Arch Linux install.
#
#  Run as your NORMAL user (do NOT run with sudo); it will ask for sudo
#  only for the steps that need root:
#
#      ./install.sh
#
#  What it does, in order:
#    1. install yay (AUR helper) if it is missing
#    2. install every package in pkg_lists.txt   (incl. qt6-5compat,
#       xorg-xsetroot, xf86-input-libinput, sddm, networkmanager, ...)
#    3. install SDKMAN, then Java 21 (Temurin) through it
#       (no JDK comes from pacman - SDKMAN owns every Java version)
#    4. install the Rust stable toolchain via rustup
#    5. enable the system services            -> sddm, NetworkManager, bluetooth,
#                                                docker, tailscale
#       and add the user to the docker group
#    6. install touchpad rules                -> tap-to-click, tap-drag,
#                                                natural scrolling
#    7. install + select the "yotsugi" SDDM login theme
#    8. install the GRUB theme
#    9. back up any clashing configs, then stow the dotfiles into $HOME
#   10. generate the default "yotsugi" pywal colourscheme + wallpaper
# ===========================================================================

set -e

# --- never run the whole thing as root (yay/makepkg/wal refuse root) --------
if [ "$(id -u)" -eq 0 ] && [ -z "$SUDO_USER" ]; then
  echo "Please run this as your normal user, NOT with sudo."
  echo "It will call sudo itself for the steps that need root."
  exit 1
fi

# --- resolve the real user / home even if invoked through sudo --------------
if [ -n "$SUDO_USER" ]; then
  USER_HOME=$(eval echo "~$SUDO_USER")
else
  USER_HOME="$HOME"
fi

DEFAULT_DIR="$(cd "$(dirname "$0")" && pwd)"

msg() { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$1"; }

# ---------------------------------------------------------------------------
install_yay() {
  if command -v yay >/dev/null 2>&1; then
    msg "yay already installed - skipping"
    return
  fi
  msg "Installing yay (AUR helper)"
  sudo pacman -S --needed --noconfirm git base-devel
  tmp="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "$tmp/yay"
  ( cd "$tmp/yay" && makepkg -si --noconfirm )
  rm -rf "$tmp"
}

# ---------------------------------------------------------------------------
install_sdkman() {
  if [ -d "$USER_HOME/.sdkman" ]; then
    msg "SDKMAN already installed - skipping"
    return
  fi
  msg "Installing SDKMAN"
  # pin the target dir so it matches the check above even under sudo;
  # ~/.config/zsh/.zshrc sources $SDKMAN_DIR/bin/sdkman-init.sh on every shell
  SDKMAN_DIR="$USER_HOME/.sdkman" curl -s "https://get.sdkman.io" | bash
}

# ---------------------------------------------------------------------------
install_java() {
  JAVA_VERSION="21-tem"   # Temurin 21 LTS
  sdkman_init="$USER_HOME/.sdkman/bin/sdkman-init.sh"

  if [ ! -s "$sdkman_init" ]; then
    msg "SDKMAN not found - skipping Java install"
    return
  fi
  if [ -d "$USER_HOME/.sdkman/candidates/java/$JAVA_VERSION" ]; then
    msg "Java $JAVA_VERSION already installed - skipping"
    return
  fi

  msg "Installing Java $JAVA_VERSION via SDKMAN"
  # `sdk` is a shell function, so source sdkman-init.sh first. sdkman_auto_answer
  # is set after sourcing (the init sources etc/config, which would reset it) so
  # the "set as default?" prompt does not block the install.
  bash -c "set +e; source '$sdkman_init'; sdkman_auto_answer=true; sdk install java $JAVA_VERSION" \
    || echo "  (Java install failed - run 'sdk install java $JAVA_VERSION' by hand)"
}

# ---------------------------------------------------------------------------
install_rust_toolchain() {
  command -v rustup >/dev/null 2>&1 || { msg "rustup not found - skipping"; return; }
  if rustup default >/dev/null 2>&1; then
    msg "Rust toolchain already installed - skipping"
    return
  fi
  # rustup ships no toolchain by default; nvim's conform.nvim calls `rustfmt`
  # and rust_analyzer needs cargo, both of which come from the stable toolchain
  msg "Installing the Rust stable toolchain"
  rustup default stable
}

# ---------------------------------------------------------------------------
install_packages() {
  msg "Installing packages from pkg_lists.txt"
  grep -v '^\s*#' "$DEFAULT_DIR/pkg_lists.txt" | grep -v '^\s*$' | yay -S --needed --noconfirm -
}

# ---------------------------------------------------------------------------
set_default_shell() {
  zsh_path="$(command -v zsh)"
  if [ -z "$zsh_path" ]; then
    msg "zsh not found - skipping default shell change"
    return
  fi
  target_user="${SUDO_USER:-$(id -un)}"
  current_shell="$(getent passwd "$target_user" | cut -d: -f7)"
  if [ "$current_shell" = "$zsh_path" ]; then
    msg "Default shell already zsh - skipping"
    return
  fi
  msg "Setting zsh as the default shell for $target_user"
  sudo chsh -s "$zsh_path" "$target_user"
}

# ---------------------------------------------------------------------------
enable_services() {
  msg "Enabling services: sddm, NetworkManager, bluetooth, docker, tailscale"
  sudo systemctl enable sddm.service
  sudo systemctl enable NetworkManager.service
  sudo systemctl enable bluetooth.service
  sudo systemctl enable docker.socket
  sudo systemctl enable tailscaled.service

  # let the normal user talk to the docker daemon without sudo
  target_user="${SUDO_USER:-$(id -un)}"
  if ! id -nG "$target_user" | grep -qw docker; then
    msg "Adding $target_user to the docker group (takes effect next login)"
    sudo usermod -aG docker "$target_user"
  fi

  # WinPodX runs Windows in a KVM-backed rootless Podman container and needs
  # /dev/kvm access; `winpodx setup-host` also fixes subuid/subgid mappings.
  if ! id -nG "$target_user" | grep -qw kvm; then
    msg "Adding $target_user to the kvm group (needed by WinPodX)"
    sudo usermod -aG kvm "$target_user"
  fi
}

# ---------------------------------------------------------------------------
install_touchpad() {
  msg "Installing touchpad rules (tap-to-click, tap-drag, natural scroll)"
  sudo install -Dm644 "$DEFAULT_DIR/system/30-touchpad.conf" \
       /etc/X11/xorg.conf.d/30-touchpad.conf
}

# ---------------------------------------------------------------------------
install_sddm_theme() {
  msg "Installing + selecting the yotsugi SDDM theme"
  sudo mkdir -p /usr/share/sddm/themes
  sudo cp -rT "$DEFAULT_DIR/.config/sddm/themes/yotsugi" \
       /usr/share/sddm/themes/yotsugi
  sudo install -Dm644 "$DEFAULT_DIR/system/sddm-theme.conf" \
       /etc/sddm.conf.d/theme.conf
}

# ---------------------------------------------------------------------------
install_grub_theme() {
  if [ ! -d /boot/grub ] || ! command -v grub-mkconfig >/dev/null 2>&1; then
    msg "GRUB not detected - skipping GRUB theme"
    return
  fi
  msg "Installing GRUB theme"
  sudo bash "$DEFAULT_DIR/grub-config/install.sh" || \
    echo "  (GRUB theme step failed - continuing)"
}

# ---------------------------------------------------------------------------
install_fetch() {
  if command -v fetch >/dev/null 2>&1; then
    msg "manas140 fetch already installed - skipping"
    return
  fi
  msg "Installing manas140 fetch"
  tmp="$(mktemp -d)"
  if git clone --depth 1 https://github.com/Manas140/fetch.git "$tmp/fetch"; then
    # install the binary system-wide; the repo's config is NOT touched, so the
    # stowed ~/.config/fetch/conf stays in charge
    sudo install -Dm755 "$tmp/fetch/fetch" /usr/local/bin/fetch
  else
    echo "  (could not clone manas140/fetch - skipping)"
  fi
  rm -rf "$tmp"
}

# ---------------------------------------------------------------------------
backup_config() {
  msg "Backing up any clashing configs"
  TIMESTAMP=$(date +%Y%m%d%H%M%S)
  BACKUP_DIR="$DEFAULT_DIR/backup/$TIMESTAMP"
  mkdir -p "$BACKUP_DIR"

  for entry in "$DEFAULT_DIR"/* "$DEFAULT_DIR"/.config/*; do
    [ -e "$entry" ] || continue
    rel_path="${entry#$DEFAULT_DIR/}"
    target_path="$USER_HOME/$rel_path"
    # only back up a REAL file/dir in the way; ignore existing stow symlinks
    if [ -e "$target_path" ] && [ ! -L "$target_path" ]; then
      mkdir -p "$(dirname "$BACKUP_DIR/$rel_path")"
      mv "$target_path" "$BACKUP_DIR/$rel_path"
    fi
  done
}

# ---------------------------------------------------------------------------
stow_dotfiles() {
  msg "Fetching the nvim submodule"
  git -C "$DEFAULT_DIR" submodule update --init --recursive || true

  msg "Linking dotfiles into $USER_HOME"
  stow -R -v -t "$USER_HOME" .
}

# ---------------------------------------------------------------------------
configure_battery() {
  msg "Detecting battery/adapter names for the polybar battery module"
  mod="$DEFAULT_DIR/.config/polybar/modules.ini"
  [ -f "$mod" ] || return

  bat=""
  adp=""
  for d in /sys/class/power_supply/*; do
    [ -e "$d/type" ] || continue
    t="$(cat "$d/type" 2>/dev/null)"
    [ -z "$bat" ] && [ "$t" = "Battery" ] && bat="$(basename "$d")"
    [ -z "$adp" ] && [ "$t" = "Mains" ]   && adp="$(basename "$d")"
  done

  if [ -n "$bat" ]; then
    sed -i "s/^battery = .*/battery = $bat/" "$mod"
    echo "  battery = $bat"
  else
    echo "  no battery found (desktop?) - leaving battery module as-is"
  fi
  if [ -n "$adp" ]; then
    sed -i "s/^adapter = .*/adapter = $adp/" "$mod"
    echo "  adapter = $adp"
  fi
}

# ---------------------------------------------------------------------------
apply_theme() {
  msg "Setting yotsugi as the default theme"
  wallpaper="$DEFAULT_DIR/Wallpapers/Yotsugi.png"

  # Colours: regenerate ~/.cache/wal/* from the yotsugi palette (works on a TTY).
  wal -q -n --theme yotsugi || echo "  (pywal step skipped)"

  # Wallpaper: persist to ~/.fehbg with --bg-fill so it covers the whole screen
  # on first login (same as the alt+t theme switcher does).
  cat > "$USER_HOME/.fehbg" <<EOF
#!/bin/sh
feh --no-fehbg --bg-fill '$wallpaper'
EOF
  chmod +x "$USER_HOME/.fehbg"

  if [ -n "$DISPLAY" ]; then
    "$USER_HOME/.fehbg" || true
    xsetroot -cursor_name left_ptr || true
  fi
}

# ===========================================================================
cd "$DEFAULT_DIR"

install_yay
install_packages
install_sdkman
install_java
install_rust_toolchain
set_default_shell
enable_services
install_touchpad
install_sddm_theme
install_grub_theme
install_fetch
backup_config
stow_dotfiles
configure_battery
apply_theme

msg "All done! Reboot to land on the SDDM login screen and pick the bspwm session."
