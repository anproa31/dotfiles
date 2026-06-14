HISTFILE=$HOME/.config/zsh/.histfile
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_ALL_DUPS
setopt no_nomatch

autoload -U compinit
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit -d "$HOME/.config/zsh/.zcompdump"
_comp_options+=(globdots)

if [[ -f "$HOME/.config/zsh/.zprofile" ]]; then
  source "$HOME/.config/zsh/.zprofile"  
fi

# Set theme
source $HOME/.config/zsh/Themes/common.zsh-theme

# Plugins
ZSH_PLUGIN_DIR="$HOME/.config/zsh/Plugins"

plugins=(
  zdharma-continuum/fast-syntax-highlighting
  zsh-users/zsh-autosuggestions
  marlonrichert/zsh-autocomplete
  jeffreytse/zsh-vi-mode
  none9632/zsh-sudo
  jirutka/zsh-shift-select
)

for plugin in "${plugins[@]}"; do
  user="${plugin%%/*}"
  repo="${plugin##*/}"

  plugin_path="$ZSH_PLUGIN_DIR/$repo"
  url="https://github.com/$plugin.git"

  if [ ! -d "$plugin_path" ] || [ -z "$(ls -A "$plugin_path")" ]; then
    echo "Cloning $repo"
    git clone --depth=1 "$url" "$plugin_path" > /dev/null 2>&1
  fi

  # Source the plugin, ensure .zsh file contain plugin name
  for file in "$plugin_path"/*.zsh(N); do
    if [[ "$(basename "$file")" == *"$repo"* ]]; then
      source "$file"
      break
    fi
  done
done

# Changing dir upon quitting lf
lf () {
  tmp="$(mktemp)"
  /usr/bin/lf --last-dir-path="$tmp" "$@"
  if [ -f "$tmp" ]; then
    dir="$(cat "$tmp")"
    rm -f "$tmp"
    if [ -d "$dir" ]; then
      if [ "$dir" != "$(pwd)" ]; then
          cd "$dir"
      fi
    fi
  fi
}

# Auto nvim . when no arg
# nvim() {
#   if [ "$#" -eq 0 ]; then
#     command nvim 
#   else
#     command nvim "$@"
#   fi
# }

# Fix a bug when you C-c in CMD mode and you'd be prompted with CMD mode indicator, while in fact you would be in INS mode
# Fixed by catching SIGINT (C-c), set vim_mode to INS and then repropagate the SIGINT, so if anything else depends on it, we will not break it
function TRAPINT() {
  vim_mode=$vim_ins_mode
  return $(( 128 + $1 ))
}

function toggle_service() {
  local SERVICE="$1"
  if systemctl is-active --quiet "$SERVICE"; then
    echo "Stopping $SERVICE..."
    sudo systemctl stop "$SERVICE"
  else
    echo "Starting $SERVICE..."
    sudo systemctl start "$SERVICE"
  fi
}

# Export
export EDITOR=nvim
export PISTOL_CHROMA_STYLE=vim
export PF_INFO="ascii title os uptime pkgs memory palette"
export PATH="$HOME/.local/bin:$PATH"

export ANDROID_HOME=$HOME/.android/SDK/
export ANDROID_SDK_ROOT=$HOME/.android/SDK/
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools

export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export PATH=$PATH:$JAVA_HOME

# Aliases
alias vim="nvim"
alias vi="nvim"
alias v="nvim"
alias nivm="nvim"

alias lsa="ls -al"

alias yeet="yay -Rsn"

alias zshcf="nvim $HOME/.config/zsh/.zshrc"
alias bspcf="nvim $HOME/.config/bspwm/bspwmrc"
alias sxhkcf="nvim $HOME/.config/sxhkd/sxhkdrc"
alias kittycf="nvim $HOME/.config/kitty/kitty.conf"

alias zshc="source $HOME/.config/zsh/.zshrc"

alias status="systemctl status"
alias warp="toggle_service warp-svc"


# WinApps aliases
alias wastart="docker compose --file ~/.config/windows-config/docker-compose.yaml start"
alias wastop="docker compose --file ~/.config/windows-config/docker-compose.yaml stop"
alias wapause="docker compose --file ~/.config/windows-config/docker-compose.yaml pause"
alias waunpause="docker compose --file ~/.config/windows-config/docker-compose.yaml unpause"
alias warestart="docker compose --file ~/.config/windows-config/docker-compose.yaml restart"
alias wakill="docker compose --file ~/.config/windows-config/docker-compose.yaml kill"
alias walogs="docker compose --file ~/.config/windows-config/docker-compose.yaml logs -f"

alias wardp="winapps windows > /dev/null 2>&1 & disown"


for sudo_typo in sduo sodu suod soud; do
  alias $sudo_typo='sudo'
done

# Init zoxide
eval "$(zoxide init zsh --cmd cd)"
eval "$(fnm env --use-on-cd)"

export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

if [ -f "$HOME/.cache/wal/sequences" ]; then
  cat "$HOME/.cache/wal/sequences"
fi

if command -v fetch> /dev/null 2>&1; then
  fetch
fi

LOG_FILE="$HOME/check_aur_mal.txt"

echo "=== AUR Malware Check ($(date)) ===" | tee "$LOG_FILE"
echo "Affected Packages Found:" | tee -a "$LOG_FILE"

comm -12 <(pacman -Qqm | sort) <(curl -s https://cscs.pastes.sh/raw/aurvulnlist20260611.txt | sort) | { 
    read -r l && { 
        printf '%s\n' "$l"
        cat
    } || echo "None. No known compromised packages are installed."
} | tee -a "$LOG_FILE"
echo "-----------------------------------" | tee -a "$LOG_FILE"
