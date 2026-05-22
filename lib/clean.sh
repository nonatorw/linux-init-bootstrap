#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# lib/clean.sh
# Teardown helpers for --clean-install, --clean-tools, and --reinstall flags.
# Sourced by bootstrap.sh; requires output helpers and state helpers.
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────
# Summary: remove all tools, managed dotfiles, and the state file; then proceed with reinstall
# ─────────────────────────────────────────────
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

# ─────────────────────────────────────────────
# Summary: remove dev tool directories and tool state entries; preserve shell, dotfiles, and system packages
# ─────────────────────────────────────────────
_clean_tools() {
  warn "--clean-tools: removing dev tools in 5 seconds (Ctrl+C to abort)"
  for i in 5 4 3 2 1; do printf '%s ' "$i"; sleep 1; done; echo

  step "Removing dev tool directories..."
  rm -rf "$HOME/Dev/tools/python" \
         "$HOME/Dev/tools/node"   \
         "$HOME/Dev/tools/java"   \
         "$HOME/Dev/tools/ai"
  ok "Dev tool directories removed"

  step "Removing /usr/local/bin/node symlink..."
  [[ -L /usr/local/bin/node ]] && sudo rm -f /usr/local/bin/node && ok "/usr/local/bin/node removed" || skip "/usr/local/bin/node symlink not found"

  step "Removing tool state entries..."
  for key in module_03_python module_04_java module_05_node module_06_ai module_07_containers; do
    state_unset "$key" 2>/dev/null || true
  done
  ok "Tool state entries removed"

  step "Running package manager cleanup..."
  case "${PKG_MANAGER:-apt}" in
    apt) run_cmd "apt autoclean" sudo apt autoclean && run_cmd "apt autoremove" sudo apt autoremove -y ;;
    dnf) run_cmd "dnf clean"    sudo dnf clean all && run_cmd "dnf autoremove" sudo dnf autoremove -y ;;
    brew) run_cmd "brew cleanup" brew cleanup && run_cmd "brew autoremove" brew autoremove ;;
  esac
  ok "Package manager cleanup done"

  success "Dev tools removed. Shell, dotfiles, and system packages are intact."
}

# ─────────────────────────────────────────────
# Summary: run _clean_tools, reset full bootstrap state, then exit to allow full reinstall
# ─────────────────────────────────────────────
_reinstall() {
  warn "--reinstall: full state reset + clean tools + complete reinstall"
  for i in 5 4 3 2 1; do printf '%s ' "$i"; sleep 1; done; echo

  _clean_tools

  step "Resetting full bootstrap state..."
  rm -f "$HOME/.bootstrap-state"
  ok "State file removed"

  success "Ready for full reinstall — re-run bootstrap.sh to continue"
  exit 0
}
