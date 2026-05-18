#!/usr/bin/env bash
# ============================================================
# bootstrap.sh — configura o ambiente de desenvolvimento
# ============================================================

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Cores
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ---------------------------------------------------------------------------
# Output helpers — used by bootstrap.sh and all install/ modules
# ---------------------------------------------------------------------------

# Main header (magenta): section_header "Title"
# Matches the *===...===* pattern from RunUpdates/RunDevUpdates.
section_header() {
  local title="$1"
  echo -e ""
  echo -e "${MAGENTA}*===========================================================================*${RESET}"
  echo -e "${MAGENTA}*  ${title}${RESET}"
  echo -e "${MAGENTA}*===========================================================================*${RESET}"
}

# Sub-section (cyan): step_header N TOTAL "Title" "tool · tool"
# Matches the *---...---* / *> [N/T] Title ---* pattern from RunDevUpdates/RunUpdates.
# Total line width: 77 chars. Title line: "*> " (3) + label + " " (1) + dashes + "*" (1) = 77
step_header() {
  local n="$1" total="$2" title="$3" tools="$4"
  local label="[${n}/${total}] ${title}"
  local dash_count=$(( 72 - ${#label} ))
  local dashes
  [[ $dash_count -gt 0 ]] && dashes="$(printf '%0.s-' $(seq 1 $dash_count))" || dashes=""
  echo -e ""
  echo -e "${CYAN}*---------------------------------------------------------------------------*${RESET}"
  echo -e "${CYAN}*> ${label} ${dashes}*${RESET}"
  echo -e "${CYAN}*  ${DIM}${tools}${RESET}"
  echo -e "${CYAN}*---------------------------------------------------------------------------*${RESET}"
}

info()    { echo -e "${CYAN}    ${RESET} $*"; }
step()    { echo -e "  ${BLUE}→${RESET} $*"; }
ok()      { echo -e "  ${GREEN}✓${RESET} $*"; }
skip()    { echo -e "  ${GREEN}✓${RESET} ${DIM}already installed${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "  ${RED}✖${RESET} $*"; exit 1; }
success() { echo -e "\n${GREEN}${BOLD}✔  $*${RESET}"; }

# ------------------------------------------------------------
# Load helpers
# ------------------------------------------------------------
source "$DOTFILES_DIR/lib/platform.sh"
detect_platform

info "Platform: $PLATFORM | Package manager: $PKG_MANAGER"

# ------------------------------------------------------------
# Run install modules in order
# ------------------------------------------------------------
_run_install() {
  mkdir -p "$HOME/Dev/tools/python/pyenv"     \
           "$HOME/Dev/tools/python/poetry"    \
           "$HOME/Dev/tools/node/nvm"         \
           "$HOME/Dev/tools/java/sdkman"      \
           "$HOME/Dev/tools/ai/claude"        \
           "$HOME/Dev/tools/ai/gemini"        \
           "$HOME/Dev/tools/ai/gemini-config" \
           "$HOME/Dev/repos"

  # ~/.ssh with correct permissions — no local keys, everything via 1Password
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  local modules=(
    "$DOTFILES_DIR/install/00_packages.sh"
    "$DOTFILES_DIR/install/01_shell.sh"
    "$DOTFILES_DIR/install/02_chezmoi.sh"
    "$DOTFILES_DIR/install/03_python.sh"
    "$DOTFILES_DIR/install/04_java.sh"
    "$DOTFILES_DIR/install/05_node.sh"
    "$DOTFILES_DIR/install/06_ai.sh"
    "$DOTFILES_DIR/install/07_containers.sh"
  )
  local total="${#modules[@]}"
  local n=0

  for module in "${modules[@]}"; do
    (( n++ )) || true
    if [[ -f "$module" ]]; then
      source "$module"
      _BOOTSTRAP_STEP_N="$n"
      _BOOTSTRAP_STEP_TOTAL="$total"
      export _BOOTSTRAP_STEP_N _BOOTSTRAP_STEP_TOTAL
      "$(basename "$module" .sh | sed 's/^[0-9]*_/install_/')" || \
        warn "Module $(basename "$module") reported an issue — continuing"
    fi
  done
}

# ------------------------------------------------------------
# Entry point
# ------------------------------------------------------------
section_header "linux-init-bootstrap — setup"
echo -e "  ${DIM}Platform: ${PLATFORM}  |  Package manager: ${PKG_MANAGER}${RESET}"

_run_install

success "Tools installed."

# ------------------------------------------------------------
# WSL2: check 1Password SSH agent prerequisite
# ------------------------------------------------------------
if [[ "$PLATFORM" == "wsl2" ]]; then
  section_header "1Password SSH Agent (WSL2)"
  _NPIPERELAY_PATH=""
  for _candidate in \
    /mnt/c/Users/*/AppData/Local/Microsoft/WinGet/Links/npiperelay.exe \
    "/mnt/c/Program Files/WinGet/Links/npiperelay.exe" \
    "/mnt/c/Program Files (x86)/WinGet/Links/npiperelay.exe"; do
    [[ -x "$_candidate" ]] && { _NPIPERELAY_PATH="$_candidate"; break; }
  done
  unset _candidate
  if [[ -x "$_NPIPERELAY_PATH" ]]; then
    ok "npiperelay found: ${DIM}${_NPIPERELAY_PATH}${RESET}"
    step "SSH agent relay will start automatically via dev_configs.sh"
  else
    warn "npiperelay.exe not found — 1Password SSH agent will not work in WSL2"
    warn "Install it on Windows: ${DIM}winget install jstarks.npiperelay${RESET}"
    warn "Enable 'Use SSH agent' in 1Password → Settings → Developer"
    warn "See README.md for full setup instructions"
  fi
  unset _NPIPERELAY_PATH
fi

# ------------------------------------------------------------
# SSH known_hosts — host keys fetched at runtime via ssh-keyscan
# ------------------------------------------------------------
_setup_ssh_known_hosts() {
  local hosts=("github.com" "gitlab.com" "bitbucket.org")
  local known="$HOME/.ssh/known_hosts"
  local added=0

  for host in "${hosts[@]}"; do
    if grep -q "^$host " "$known" 2>/dev/null; then
      skip "known_hosts: $host"
    else
      step "Fetching host key for $host..."
      ssh-keyscan -t ed25519 "$host" >> "$known" 2>/dev/null || true
      ok "known_hosts: $host"
      (( added++ )) || true
    fi
  done

  [[ $added -gt 0 ]] && chmod 600 "$known"
}

# ------------------------------------------------------------
# Apply dotfiles via chezmoi
# ------------------------------------------------------------
_apply_dotfiles() {
  # Clone uses HTTPS (no auth required for public repo) because the SSH agent
  # relay (socat + npiperelay) is not yet active at this point in the bootstrap.
  # The relay starts automatically on the next terminal session via dev_configs.sh.
  # SSH host keys are already populated by _setup_ssh_known_hosts above so that
  # git push works immediately after reopening the terminal.
  local repo="https://github.com/nonatorw/chezmoi-dotfiles.git"
  local dest="$HOME/Dev/repos/chezmoi-dotfiles"
  local chezmoi_bin
  chezmoi_bin="$(command -v chezmoi 2>/dev/null || echo "$HOME/.local/bin/chezmoi")"

  section_header "Dotfiles"

  if [[ -d "$dest/.git" ]]; then
    skip "chezmoi-dotfiles  ${DIM}($dest)${RESET}"
  else
    step "Cloning chezmoi-dotfiles to ${DIM}$dest${RESET}..."
    if ! GIT_CONFIG_NOSYSTEM=1 HOME=/tmp git clone "$repo" "$dest"; then
      warn "Failed to clone $repo"
      warn "Check: repo exists and is public, or run manually: git clone $repo $dest"
      return 1
    fi
    ok "chezmoi-dotfiles cloned"
  fi

  mkdir -p "$HOME/.config/chezmoi"
  local toml="$HOME/.config/chezmoi/chezmoi.toml"
  if [[ ! -f "$toml" ]]; then
    printf 'sourceDir = "%s"\n' "$dest" > "$toml"
    ok "chezmoi.toml created  ${DIM}(sourceDir = $dest)${RESET}"
  else
    skip "chezmoi.toml  ${DIM}($(cat "$toml"))${RESET}"
  fi

  step "Applying dotfiles..."
  if ! "$chezmoi_bin" apply --force; then
    warn "chezmoi apply failed — dotfiles may be partially applied"
    warn "Run manually: $chezmoi_bin apply --force"
    return 1
  fi
  ok "Dotfiles applied"
}

_setup_ssh_known_hosts || warn "SSH known_hosts setup had issues — continuing"
_apply_dotfiles || warn "Dotfiles apply had issues — check warnings above"

echo ""
success "Bootstrap complete! Restart your terminal to apply all changes."
echo ""
