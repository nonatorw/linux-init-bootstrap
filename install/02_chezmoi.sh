#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# install/02_chezmoi.sh
# Dotfile manager: install chezmoi to ~/.local/bin.
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────
# Summary: install chezmoi to ~/.local/bin if not already present
# ─────────────────────────────────────────────
install_chezmoi() {
  step_header "${_BOOTSTRAP_STEP_N}" "${_BOOTSTRAP_STEP_TOTAL}" \
    "chezmoi" "dotfile manager"

  # Ensure ~/.local/bin is in the current session PATH (curl installers place binaries here)
  export PATH="$HOME/.local/bin:$PATH"

  if has chezmoi; then
    skip "$(chezmoi --version)"
    return 0
  fi
  step "Installing chezmoi to ~/.local/bin..."
  run_cmd "chezmoi install" sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
  ok "$(chezmoi --version)"
}
