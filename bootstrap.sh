#!/usr/bin/env bash
# ============================================================
# bootstrap.sh — Phase 3: development environment setup
# ============================================================
#
# Usage:
#   bash bootstrap.sh                  # install / resume from last state
#   bash bootstrap.sh --clean-install  # wipe all tools + dotfiles, then reinstall
#
# On WSL2, automatically invokes setup-windows.ps1 first (non-admin Windows checks).
# For admin Windows prerequisites, run setup-windows-admin.ps1 manually beforehand.
# For WSL-level prerequisites, run setup-wsl.sh before this script.

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Flag parsing
# ---------------------------------------------------------------------------
CLEAN_INSTALL=false
for arg in "$@"; do
  [[ "$arg" == "--clean-install" ]] && CLEAN_INSTALL=true
done

# ---------------------------------------------------------------------------
# Colors
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

# Main header (magenta)
section_header() {
  local title="$1"
  echo -e ""
  echo -e "${MAGENTA}*===========================================================================*${RESET}"
  echo -e "${MAGENTA}*  ${title}${RESET}"
  echo -e "${MAGENTA}*===========================================================================*${RESET}"
}

# Sub-section (cyan): step_header N TOTAL "Title" "tool · tool"
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

# ---------------------------------------------------------------------------
# Load platform detection and state helpers
# ---------------------------------------------------------------------------
source "$BOOTSTRAP_DIR/lib/platform.sh"
source "$BOOTSTRAP_DIR/lib/state.sh"
detect_platform
state_init

# ---------------------------------------------------------------------------
# --clean-install: wipe all tools, dotfiles, and state before reinstalling
# ---------------------------------------------------------------------------
if [[ "$CLEAN_INSTALL" == "true" ]]; then
  source "$BOOTSTRAP_DIR/lib/clean.sh"
  _clean_install
fi

section_header "linux-init-bootstrap — Phase 3: tools"
echo -e "  ${DIM}Platform: ${PLATFORM}  |  Package manager: ${PKG_MANAGER}${RESET}"

# ---------------------------------------------------------------------------
# Phase 1: Windows prerequisites (WSL2 only, non-admin, auto-invoked)
# ---------------------------------------------------------------------------
if [[ "$PLATFORM" == "wsl2" ]]; then
  local_ps_script="$BOOTSTRAP_DIR/setup-windows.ps1"
  if [[ -f "$local_ps_script" ]]; then
    # Ensure state file exists with correct ownership before PowerShell writes to it
    state_init
    win_script="$(wslpath -w "$local_ps_script")"
    win_state_file="$(wslpath -w "$STATE_FILE")"
    powershell.exe -ExecutionPolicy Bypass \
      -File "$win_script" -StateFile "$win_state_file" || \
      warn "Windows prerequisites check had issues — see output above"
  else
    warn "setup-windows.ps1 not found — skipping Windows prerequisites check"
  fi
fi

# ---------------------------------------------------------------------------
# Module runner with state integration
# ---------------------------------------------------------------------------
_run_module() {
  local n="$1" total="$2" module="$3"
  local key="module_$(basename "$module" .sh)"

  if state_is "$key" "complete"; then
    skip "$(basename "$module") — already complete"
    return 0
  fi

  state_set "$key" "in_progress"
  # shellcheck source=/dev/null
  source "$module"
  _BOOTSTRAP_STEP_N="$n"
  _BOOTSTRAP_STEP_TOTAL="$total"
  export _BOOTSTRAP_STEP_N _BOOTSTRAP_STEP_TOTAL

  local fn_name
  fn_name="$(basename "$module" .sh | sed 's/^[0-9]*_/install_/')"

  if "$fn_name"; then
    state_set "$key" "complete"
  else
    state_set "$key" "failed"
    warn "Module $(basename "$module") reported an issue — continuing"
  fi
}

# ---------------------------------------------------------------------------
# Phase 3: Install development tools
# ---------------------------------------------------------------------------
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
    "$BOOTSTRAP_DIR/install/00_packages.sh"
    "$BOOTSTRAP_DIR/install/01_shell.sh"
    "$BOOTSTRAP_DIR/install/02_chezmoi.sh"
    "$BOOTSTRAP_DIR/install/03_python.sh"
    "$BOOTSTRAP_DIR/install/04_java.sh"
    "$BOOTSTRAP_DIR/install/05_node.sh"
    "$BOOTSTRAP_DIR/install/06_ai.sh"
    "$BOOTSTRAP_DIR/install/07_containers.sh"
  )
  local total="${#modules[@]}"
  local n=0

  for module in "${modules[@]}"; do
    (( n++ )) || true
    [[ -f "$module" ]] && _run_module "$n" "$total" "$module"
  done
}

_run_install
state_set "phase_tools" "complete"
success "Tools installed."

# ---------------------------------------------------------------------------
# SSH known_hosts — host keys fetched at runtime via ssh-keyscan
# ---------------------------------------------------------------------------
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
  return 0
}

# ---------------------------------------------------------------------------
# Resolve SSH signing key for chezmoi data
# ---------------------------------------------------------------------------
_resolve_signing_key() {
  # All UI output goes to stderr — stdout is reserved for the key value only.

  # 1. Already captured by setup-windows.ps1 or a previous run
  local cached
  cached="$(state_get "signing_key")"
  if [[ -n "$cached" ]]; then
    ok "signing_key loaded from state file" >&2
    echo "$cached"
    return 0
  fi

  # 2. Try to read from the SSH agent (1Password via ssh-add / ssh-add.exe)
  local ssh_add_bin="ssh-add"
  [[ "$PLATFORM" == "wsl2" ]] && ssh_add_bin="ssh-add.exe"

  local -a keys=()
  local key_count=0

  while true; do
    local raw
    raw="$("$ssh_add_bin" -L 2>/dev/null)" || raw=""
    mapfile -t keys < <(echo "$raw" | grep -E "^(sk-)?(ssh-|ecdsa-)" || true)
    key_count="${#keys[@]}"

    if [[ "$key_count" -gt 0 ]]; then
      break
    fi

    warn "No SSH keys found in 1Password agent." >&2
    echo "" >&2
    info "Configure 1Password Desktop before continuing:" >&2
    info "  1. Open 1Password → Settings → Developer" >&2
    info "       - Enable 'Use the SSH agent'" >&2
    info "       - Enable 'Integrate with 1Password CLI'" >&2
    info "  2. Your SSH key must be a native SSH Key item" >&2
    info "       (New Item → SSH Key → import private key file)" >&2
    echo "" >&2
    printf "  [R]etry / [C]ancel: " >&2
    local choice
    read -r choice
    if [[ "$choice" =~ ^[Cc] ]]; then
      warn "Cancelled by user — dotfiles not applied" >&2
      warn "Re-run bootstrap after configuring 1Password SSH agent: bash bootstrap.sh" >&2
      return 1
    fi
  done

  local signing_key
  if [[ "$key_count" -eq 1 ]]; then
    signing_key="${keys[0]}"
    ok "SSH signing key detected automatically" >&2
  else
    echo "" >&2
    info "Multiple SSH keys found — select the signing key:" >&2
    local i
    for (( i=0; i<key_count; i++ )); do
      printf "    [%d] %.70s...\n" $(( i+1 )) "${keys[$i]}" >&2
    done
    echo "" >&2
    local sel
    while true; do
      printf "  Enter number (1-%d) or [C]ancel: " "$key_count" >&2
      read -r sel
      if [[ "$sel" =~ ^[Cc] ]]; then
        warn "Cancelled by user — dotfiles not applied" >&2
        warn "Re-run bootstrap after selecting a signing key: bash bootstrap.sh" >&2
        return 1
      fi
      if [[ "$sel" =~ ^[0-9]+$ ]] && (( sel >= 1 && sel <= key_count )); then
        signing_key="${keys[$(( sel-1 ))]}"
        break
      fi
      warn "Invalid selection — enter a number between 1 and $key_count, or C to cancel" >&2
    done
    ok "SSH signing key selected" >&2
  fi

  state_set "signing_key" "$signing_key"
  echo "$signing_key"
}

# ---------------------------------------------------------------------------
# Apply dotfiles via chezmoi
# ---------------------------------------------------------------------------
_apply_dotfiles() {
  # Clone uses HTTPS (no auth required for public repo) because the SSH agent
  # is not yet active at this point in the bootstrap. It becomes available
  # after the first terminal restart via the aliases defined in aliases.sh.
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

  local toml="$HOME/.config/chezmoi/chezmoi.toml"
  if [[ -f "$toml" ]]; then
    # Validate that the toml is readable by chezmoi before skipping init
    if "$chezmoi_bin" cat-config >/dev/null 2>&1; then
      skip "chezmoi.toml already exists — skipping init"
      step "Applying dotfiles..."
      if ! "$chezmoi_bin" apply --force; then
        warn "chezmoi apply failed — dotfiles may be partially applied"
        warn "Run manually: $chezmoi_bin apply --force"
        return 1
      fi
      ok "Dotfiles applied"
      return 0
    else
      warn "chezmoi.toml exists but is invalid — regenerating"
      rm -f "$toml"
    fi
  fi

  # chezmoi.toml does not exist — resolve signing key, write toml, then apply
  step "Resolving SSH signing key..."
  local signing_key
  if ! signing_key="$(_resolve_signing_key)"; then
    warn "SSH signing key not resolved — dotfiles not applied"
    warn "Fix 1Password SSH agent setup and re-run: bash bootstrap.sh"
    return 1
  fi

  # Write chezmoi.toml with signingKey before init so promptStringOnce finds it
  # and does not prompt the user interactively.
  mkdir -p "$HOME/.config/chezmoi"
  cat > "$toml" <<EOF
sourceDir = "$dest"

[data]
  signingKey = "$signing_key"
EOF
  ok "chezmoi.toml created with signingKey"

  step "Applying dotfiles (source: ${DIM}$dest${RESET})..."
  if ! "$chezmoi_bin" apply --force; then
    warn "chezmoi apply failed — dotfiles may be partially applied"
    warn "Run manually: $chezmoi_bin apply --force"
    return 1
  fi
  ok "Dotfiles applied"
}

_setup_ssh_known_hosts || warn "SSH known_hosts setup had issues — continuing"
_apply_dotfiles        || warn "Dotfiles not applied — check warnings above and re-run: bash bootstrap.sh"
state_set "phase_dotfiles" "complete"

echo ""
success "Bootstrap complete! Restart your terminal to apply all changes."
echo ""
