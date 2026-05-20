#!/usr/bin/env bash
# ============================================================
# lib/clean.sh — --clean-install teardown
# ============================================================
#
# Removes all installed tools, managed dotfiles, and the bootstrap state file.
# Called by bootstrap.sh when --clean-install flag is passed.
# Requires output helpers (warn, ok) to be defined before sourcing this file.

_clean_install() {
  warn "--clean-install: removing all tools and dotfiles in 5 seconds (Ctrl+C to abort)"
  for i in 5 4 3 2 1; do printf '%s ' "$i"; sleep 1; done; echo

  step "Removing tool directories..."
  rm -rf "$HOME/Dev/tools"
  ok "Tool directories removed"

  local chezmoi_bin
  chezmoi_bin="$(command -v chezmoi 2>/dev/null || echo "$HOME/.local/bin/chezmoi")"
  if [[ -x "$chezmoi_bin" ]]; then
    step "Removing managed dotfiles via chezmoi..."
    "$chezmoi_bin" purge --force 2>/dev/null || true
    ok "Managed dotfiles removed"
  else
    info "chezmoi not found — skipping dotfile removal"
  fi

  step "Removing bootstrap state file..."
  rm -f "$HOME/.bootstrap-state"
  ok "State file removed"

  success "Clean install complete — all tools and dotfiles removed"
}
