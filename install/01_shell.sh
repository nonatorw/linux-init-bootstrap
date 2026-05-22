#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install/01_shell.sh
# Shell environment: Oh My Zsh, Powerlevel10k theme, and zsh plugins.
# ─────────────────────────────────────────────────────────────────────────────

OMZ_DIR="$HOME/.oh-my-zsh"
OMZ_CUSTOM="${ZSH_CUSTOM:-$OMZ_DIR/custom}"

# ─────────────────────────────────────────────
# Summary: install Oh My Zsh, Powerlevel10k theme, and zsh plugins
# ─────────────────────────────────────────────
install_shell() {
  step_header "${_BOOTSTRAP_STEP_N}" "${_BOOTSTRAP_STEP_TOTAL}" \
    "Shell" "Oh My Zsh · Powerlevel10k · plugins"

  _install_omz
  _install_p10k
  _install_zsh_plugins
}

# ─────────────────────────────────────────────
# Summary: clone and install Oh My Zsh to ~/.oh-my-zsh
# ─────────────────────────────────────────────
_install_omz() {
  # Check the main file — -d alone does not guarantee a complete install
  if [[ -f "$OMZ_DIR/oh-my-zsh.sh" ]]; then
    skip "Oh My Zsh"
    return 0
  fi
  # Remove partial directory if it exists
  [[ -d "$OMZ_DIR" ]] && rm -rf "$OMZ_DIR"
  step "Installing Oh My Zsh..."
  # RUNZSH=no prevents the installer from switching the shell interactively
  RUNZSH=no CHSH=no \
    run_cmd "omz install" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ok "Oh My Zsh installed"
}

# ─────────────────────────────────────────────
# Summary: clone Powerlevel10k theme into the Oh My Zsh custom themes directory
# ─────────────────────────────────────────────
_install_p10k() {
  local p10k_dir="$OMZ_CUSTOM/themes/powerlevel10k"
  # Check the main theme file
  if [[ -f "$p10k_dir/powerlevel10k.zsh-theme" ]]; then
    skip "Powerlevel10k"
    return 0
  fi
  [[ -d "$p10k_dir" ]] && rm -rf "$p10k_dir"
  step "Installing Powerlevel10k theme..."
  run_cmd "git clone powerlevel10k" GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
  ok "Powerlevel10k installed"
}

# ─────────────────────────────────────────────
# Summary: clone zsh plugins (autosuggestions, syntax-highlighting, history-search, completions, bat, z)
# ─────────────────────────────────────────────
_install_zsh_plugins() {
  step "Installing zsh plugins..."

  declare -A plugins=(
    ["zsh-autosuggestions"]="https://github.com/zsh-users/zsh-autosuggestions"
    ["zsh-syntax-highlighting"]="https://github.com/zsh-users/zsh-syntax-highlighting"
    ["zsh-history-substring-search"]="https://github.com/zsh-users/zsh-history-substring-search"
    ["zsh-completions"]="https://github.com/zsh-users/zsh-completions"
    ["zsh-bat"]="https://github.com/fdellwing/zsh-bat"
    ["zsh-z"]="https://github.com/agkozak/zsh-z"
  )

  # Main file per plugin — used for integrity checking
  declare -A plugin_main=(
    ["zsh-autosuggestions"]="zsh-autosuggestions.plugin.zsh"
    ["zsh-syntax-highlighting"]="zsh-syntax-highlighting.plugin.zsh"
    ["zsh-history-substring-search"]="zsh-history-substring-search.plugin.zsh"
    ["zsh-completions"]="zsh-completions.plugin.zsh"
    ["zsh-bat"]="zsh-bat.plugin.zsh"
    ["zsh-z"]="zsh-z.plugin.zsh"
  )

  for plugin in "${!plugins[@]}"; do
    local plugin_dir="$OMZ_CUSTOM/plugins/$plugin"
    local main_file="${plugin_main[$plugin]}"
    if [[ -f "$plugin_dir/$main_file" ]]; then
      skip "$plugin"
    else
      [[ -d "$plugin_dir" ]] && rm -rf "$plugin_dir"
      step "  Installing $plugin..."
      run_cmd "git clone $plugin" GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone --depth=1 "${plugins[$plugin]}" "$plugin_dir"
      ok "  $plugin"
    fi
  done
}
