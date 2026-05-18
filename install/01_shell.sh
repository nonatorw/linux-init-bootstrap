#!/usr/bin/env bash
# ============================================================
# 01_shell.sh — Oh My Zsh + Powerlevel10k + plugins
# ============================================================

OMZ_DIR="$HOME/.oh-my-zsh"
OMZ_CUSTOM="${ZSH_CUSTOM:-$OMZ_DIR/custom}"

install_shell() {
  echo "[shell] Configuring shell environment..."

  _install_omz
  _install_p10k
  _install_zsh_plugins
}

_install_omz() {
  if [[ -d "$OMZ_DIR" ]]; then
    echo "[shell] Oh My Zsh already installed — skipping"
    return 0
  fi
  echo "[shell] Installing Oh My Zsh..."
  # RUNZSH=no evita que o installer troque o shell interativamente
  RUNZSH=no CHSH=no \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
}

_install_p10k() {
  local p10k_dir="$OMZ_CUSTOM/themes/powerlevel10k"
  if [[ -d "$p10k_dir" ]]; then
    echo "[shell] Powerlevel10k already installed — skipping"
    return 0
  fi
  echo "[shell] Installing Powerlevel10k..."
  GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
}

_install_zsh_plugins() {
  echo "[shell] Installing zsh plugins..."

  declare -A plugins=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
    ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting"
    ["zsh-history-substring-search"]="https://github.com/zsh-users/zsh-history-substring-search"
    ["zsh-completions"]="https://github.com/zsh-users/zsh-completions"
    ["zsh-bat"]="https://github.com/fdellwing/zsh-bat"
    ["zsh-z"]="https://github.com/agkozak/zsh-z"
  )

  for plugin in "${!plugins[@]}"; do
    local plugin_dir="$OMZ_CUSTOM/plugins/$plugin"
    if [[ -d "$plugin_dir" ]]; then
      echo "[shell] $plugin already installed — skipping"
    else
      echo "[shell] Installing $plugin..."
      GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone --depth=1 "${plugins[$plugin]}" "$plugin_dir"
    fi
  done
}
