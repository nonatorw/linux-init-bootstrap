#!/usr/bin/env bash
# ============================================================
# 02_chezmoi.sh — chezmoi (dotfiles manager)
# ============================================================

install_chezmoi() {
  step_header "${_BOOTSTRAP_STEP_N}" "${_BOOTSTRAP_STEP_TOTAL}" \
    "chezmoi" "dotfile manager"

  # Garante ~/.local/bin no PATH da sessão atual (curl installers colocam binários aqui)
  export PATH="$HOME/.local/bin:$PATH"

  if has chezmoi; then
    skip "$(chezmoi --version)"
    return 0
  fi
  step "Installing chezmoi to ~/.local/bin..."
  sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
  ok "$(chezmoi --version)"
}
