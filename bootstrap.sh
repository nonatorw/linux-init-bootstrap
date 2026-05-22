#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# bootstrap.sh
# Main orchestrator for Phase 3: development environment setup.
# Sources lib/ helpers, detects platform, runs install modules in order,
# then applies dotfiles via chezmoi.
#
# Usage:
#   bash bootstrap.sh                  # install / resume from last state
#   bash bootstrap.sh --verbose        # show external tool output in terminal
#   bash bootstrap.sh --clean-install  # wipe all tools + dotfiles, then reinstall
#   bash bootstrap.sh --clean-tools    # remove dev tools only (keeps shell + dotfiles)
#   bash bootstrap.sh --reinstall      # full state reset + reinstall from scratch
#   bash bootstrap.sh --help           # show flag reference
#   bash bootstrap.sh --help <flag>    # show detail for a specific flag
#
# On WSL2, automatically invokes setup-windows.ps1 first (non-admin Windows checks).
# For admin Windows prerequisites, run setup-windows-admin.ps1 manually beforehand.
# For Linux prerequisites, run setup-prereqs-linux.sh before this script.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load output helpers (colors and functions)
source "$BOOTSTRAP_DIR/lib/output.sh"

CLEAN_INSTALL=false
CLEAN_TOOLS=false
REINSTALL=false
VERBOSE=false
HELP_FLAG=false
HELP_TARGET=""

for arg in "$@"; do
  case "$arg" in
    --clean-install) CLEAN_INSTALL=true ;;
    --clean-tools)   CLEAN_TOOLS=true ;;
    --reinstall)     REINSTALL=true ;;
    --verbose)       VERBOSE=true ;;
    --help)          HELP_FLAG=true ;;
    --help=*)        HELP_FLAG=true; HELP_TARGET="${arg#--help=}" ;;
    *)               [[ "$HELP_FLAG" == "true" && -z "$HELP_TARGET" ]] && HELP_TARGET="$arg" || true ;;
  esac
done
export VERBOSE

# ─────────────────────────────────────────────
# Summary: print the flag reference; with $1 set, print expanded detail for that flag
# Args:    $1 — optional flag name (e.g. "--verbose") for expanded detail
# ─────────────────────────────────────────────
_show_help() {
  local target="$1"
  if [[ -z "$target" ]]; then
    echo -e ""
    section_header "bootstrap.sh — flag reference"
    echo -e "  ${CYAN}--help${RESET}            This help. ${DIM}--help <flag>${RESET} for detail."
    echo -e "  ${CYAN}--verbose${RESET}         Show external tool output in terminal (delimited blocks)."
    echo -e "  ${CYAN}--clean-install${RESET}   Remove all tools + dotfiles + state, then reinstall."
    echo -e "  ${CYAN}--clean-tools${RESET}     Remove dev tools only. Preserves shell, dotfiles, packages."
    echo -e "  ${CYAN}--reinstall${RESET}       Full state reset + clean tools + complete reinstall."
    echo -e ""
    return
  fi
  case "$target" in
    --verbose|verbose)
      echo -e ""
      echo -e "  ${CYAN}--verbose${RESET}"
      echo -e "  Show output from external tools (apt, git clone, curl installers) in the"
      echo -e "  terminal, wrapped in delimited blocks. Always written to log file regardless."
      echo -e ""
      echo -e "  ${DIM}Example:${RESET}  bash bootstrap.sh --verbose"
      echo -e "" ;;
    --clean-tools|clean-tools)
      echo -e ""
      echo -e "  ${CYAN}--clean-tools${RESET}"
      echo -e "  Removes: ~/Dev/tools/python, node, java, ai; /usr/local/bin/node symlink;"
      echo -e "  state entries for modules 03–07; runs apt/dnf/brew cleanup."
      echo -e "  Preserves: Oh My Zsh, Powerlevel10k, plugins, chezmoi dotfiles, system packages."
      echo -e ""
      echo -e "  ${DIM}Example:${RESET}  bash bootstrap.sh --clean-tools"
      echo -e "" ;;
    --reinstall|reinstall)
      echo -e ""
      echo -e "  ${CYAN}--reinstall${RESET}"
      echo -e "  Equivalent to --clean-tools + full state reset + complete bootstrap run."
      echo -e "  Removes all tool state and re-runs all phases from scratch."
      echo -e ""
      echo -e "  ${DIM}Example:${RESET}  bash bootstrap.sh --reinstall"
      echo -e "" ;;
    --clean-install|clean-install)
      echo -e ""
      echo -e "  ${CYAN}--clean-install${RESET}"
      echo -e "  Removes everything: tools, dotfiles (via chezmoi purge), and state file."
      echo -e "  Then runs a complete reinstall. Use --reinstall to keep dotfiles."
      echo -e ""
      echo -e "  ${DIM}Example:${RESET}  bash bootstrap.sh --clean-install"
      echo -e "" ;;
    *)
      warn "Unknown flag: $target"
      echo -e "  Run ${DIM}bash bootstrap.sh --help${RESET} for the full flag list."
      echo -e "" ;;
  esac
}

if [[ "$HELP_FLAG" == "true" ]]; then
  _show_help "$HELP_TARGET"
  exit 0
fi

source "$BOOTSTRAP_DIR/lib/platform.sh"
source "$BOOTSTRAP_DIR/lib/state.sh"
source "$BOOTSTRAP_DIR/lib/ssh.sh"
source "$BOOTSTRAP_DIR/lib/dotfiles.sh"
detect_platform
state_init

source "$BOOTSTRAP_DIR/lib/clean.sh"

if [[ "$CLEAN_INSTALL" == "true" ]]; then
  _clean_install
fi

if [[ "$CLEAN_TOOLS" == "true" ]]; then
  _clean_tools
  exit 0
fi

if [[ "$REINSTALL" == "true" ]]; then
  _reinstall
fi

section_header "linux-init-bootstrap — Phase 3: tools"
echo -e "  ${DIM}Platform: ${PLATFORM}  |  Package manager: ${PKG_MANAGER}${RESET}"

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

# ─────────────────────────────────────────────
# Summary: source and run a single install module, tracking state before and after
# Args:    $1 — step number; $2 — total steps; $3 — path to module .sh file
# ─────────────────────────────────────────────
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

# ─────────────────────────────────────────────
# Summary: create tool directories and run all install modules in order
# ─────────────────────────────────────────────
_run_install() {
  mkdir -p "$HOME/Dev/tools/python/pyenv"     \
           "$HOME/Dev/tools/python/poetry"    \
           "$HOME/Dev/tools/node/nvm"         \
           "$HOME/Dev/tools/java/sdkman"      \
           "$HOME/Dev/tools/ai/claude"        \
           "$HOME/Dev/tools/ai/gemini"        \
           "$HOME/Dev/tools/ai/gemini-config" \
           "$HOME/Dev/repos"

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

mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
_setup_ssh_known_hosts || warn "SSH known_hosts setup had issues — continuing"

_run_install
state_set "phase_tools" "complete"
success "Tools installed."

_apply_dotfiles        || warn "Dotfiles not applied — check warnings above and re-run: bash bootstrap.sh"
state_set "phase_dotfiles" "complete"

echo ""
success "Bootstrap complete! Restart your terminal to apply all changes."
section_header "Post-install manual steps"
echo -e "  ${BLUE}→${RESET} Claude Code — follow the onboarding steps:"
echo -e "    ${DIM}claude${RESET}"
echo -e ""
echo -e "  ${BLUE}→${RESET} Gemini CLI — follow the onboarding steps:"
echo -e "    ${DIM}gemini${RESET}"
echo -e ""
echo -e "  ${BLUE}→${RESET} GitHub Copilot CLI — install and follow the onboarding steps:"
echo -e "    ${DIM}gh auth login${RESET}"
echo -e "    ${DIM}gh extension install github/gh-copilot${RESET}"
echo -e "    ${DIM}gh copilot --version${RESET}"
echo -e ""
