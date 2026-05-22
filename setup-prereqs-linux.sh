#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# setup-prereqs-linux.sh — Phase 2: Linux prerequisites
# Run before bootstrap.sh on any Linux system (WSL2 or standalone).
# Installs the minimal packages required by the main bootstrap (curl, git).
# Standalone — does not source lib/.
#
# Usage:
#   bash setup-prereqs-linux.sh
#   # restart if instructed, then:
#   bash bootstrap.sh
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colours duplicated here so setup-prereqs-linux.sh is standalone (lib/output.sh not yet available)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# ─────────────────────────────────────────────
# Summary: print a top-level section header with ━━━ border
# Args:    $1 — title text
# ─────────────────────────────────────────────
section_header() {
  local title="$1"
  echo -e ""
  echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${MAGENTA}  ${title}${RESET}"
  echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

info()    { echo -e "${CYAN}    ${RESET} $*"; }
step()    { echo -e "  ${BLUE}→${RESET} $*"; }
ok()      { echo -e "  ${GREEN}✓${RESET} $*"; }
skip()    { echo -e "  ${GREEN}✓${RESET} ${DIM}already installed${RESET}  $*"; }
warn()    { echo -e "  ${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "  ${RED}✖${RESET} $*"; exit 1; }
success() { echo -e "\n${GREEN}${BOLD}✔  $*${RESET}"; }

# State helpers inline — state.sh may not exist on a fresh WSL install
STATE_FILE="$HOME/.bootstrap-state"
state_init() { touch "$STATE_FILE"; }
state_set()  { sed -i "/^${1}=/d" "$STATE_FILE" 2>/dev/null || true; echo "${1}=${2}" >> "$STATE_FILE"; }
state_get()  { grep -m1 "^${1}=" "$STATE_FILE" 2>/dev/null | cut -d= -f2-; }
state_is()   { [[ "$(state_get "$1")" == "$2" ]]; }

# ─────────────────────────────────────────────
# Summary: detect the system package manager (apt or dnf)
# Outputs: "apt", "dnf", or "unknown" on stdout
# ─────────────────────────────────────────────
detect_pkg_manager() {
  if command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  else
    echo "unknown"
  fi
}

WSL_PREREQS=(curl git)

# ─────────────────────────────────────────────
# Summary: update the package index and install any missing WSL_PREREQS
# ─────────────────────────────────────────────
_install_wsl_prereqs() {
  local pkg_manager
  pkg_manager="$(detect_pkg_manager)"

  if [[ "$pkg_manager" == "unknown" ]]; then
    error "Unsupported package manager — install curl, git manually"
  fi

  step "Updating package index..."
  case "$pkg_manager" in
    apt) sudo apt-get update -qq ;;
    dnf) sudo dnf check-update -q || true ;;
  esac

  local missing=()
  for pkg in "${WSL_PREREQS[@]}"; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
      missing+=("$pkg")
    else
      skip "$pkg"
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    step "Installing: ${missing[*]}"
    case "$pkg_manager" in
      apt) sudo apt-get install -y "${missing[@]}" ;;
      dnf) sudo dnf install -y "${missing[@]}" ;;
    esac
    for pkg in "${missing[@]}"; do
      ok "$pkg installed"
    done
  fi
}

# ─────────────────────────────────────────────
# Summary: check for pending kernel updates and advise a WSL restart if needed
# ─────────────────────────────────────────────
_check_wsl_restart() {
  if [[ -f /var/run/reboot-required ]]; then
    warn "A WSL restart is recommended before running bootstrap.sh"
    warn "Run: wsl --shutdown  (from Windows PowerShell), then reopen WSL"
    return 0
  fi
  ok "No WSL restart required"
}

section_header "linux-init-bootstrap — Phase 2: Linux prerequisites"

state_init

if state_is "phase_wsl" "complete"; then
  ok "Phase 2 already complete — skipping"
  info "To re-run, remove the state entry: sed -i '/^phase_wsl=/d' ~/.bootstrap-state"
else
  _install_wsl_prereqs
  _check_wsl_restart
  state_set "phase_wsl" "complete"
fi

echo ""
success "Linux prerequisites ready. Run: bash bootstrap.sh"
echo ""
