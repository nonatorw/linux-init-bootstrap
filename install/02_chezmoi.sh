#!/usr/bin/env bash
# ============================================================
# 02_chezmoi.sh — chezmoi (dotfiles manager)
# ============================================================

install_chezmoi() {
  if has chezmoi; then
    echo "[chezmoi] chezmoi already installed: $(chezmoi --version)"
    return 0
  fi
  echo "[chezmoi] Installing chezmoi..."
  pkg_install chezmoi
  echo "[chezmoi] chezmoi: $(chezmoi --version)"
}
