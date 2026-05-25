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
  warn "--clean-install: this will permanently remove all tools, dotfiles, and the state file."
  printf "  Continue? [y/N]: "
  local confirm
  read -r confirm </dev/tty
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    warn "Aborted by user"
    return 0
  fi

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
# Summary: remove dev tool directories and tool state entries without prompting
# Called internally by _clean_tools (after confirmation) and _reinstall (after its own confirmation)
# ─────────────────────────────────────────────
_do_clean_tools() {
  step "Removing dev tool directories..."
  rm -rf "$HOME/Dev/tools/python" \
         "$HOME/Dev/tools/node"   \
         "$HOME/Dev/tools/java"   \
         "$HOME/Dev/tools/ai"
  ok "Dev tool directories removed"

  step "Removing /usr/local/bin/node symlink..."
  [[ -L /usr/local/bin/node ]] && sudo rm -f /usr/local/bin/node && ok "/usr/local/bin/node removed" || skip "/usr/local/bin/node symlink not found"

  step "Removing tool state entries..."
  for prefix in module_03 module_04 module_05 module_06 module_07; do
    state_unset_prefix "$prefix"
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
# Summary: confirm with user then remove dev tool directories and tool state entries;
#          preserves shell, dotfiles, and system packages
# ─────────────────────────────────────────────
_clean_tools() {
  warn "--clean-tools: this will remove all dev tool directories and tool state entries."
  printf "  Continue? [y/N]: "
  local confirm
  read -r confirm </dev/tty
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    warn "Aborted by user"
    return 0
  fi

  _do_clean_tools
}

# ─────────────────────────────────────────────
# Summary: confirm with user, run _do_clean_tools, reset full bootstrap state, then exit
# ─────────────────────────────────────────────
_reinstall() {
  warn "--reinstall: this will remove all dev tools, reset the full bootstrap state, and trigger a complete reinstall."
  printf "  Continue? [y/N]: "
  local confirm
  read -r confirm </dev/tty
  if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    warn "Aborted by user"
    return 0
  fi

  _do_clean_tools

  step "Resetting full bootstrap state..."
  rm -f "$HOME/.bootstrap-state"
  ok "State file removed"

  success "Ready for full reinstall — re-run bootstrap.sh to continue"
  exit 0
}
