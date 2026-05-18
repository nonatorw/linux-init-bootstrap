#!/usr/bin/env bash
# ============================================================
# bootstrap.sh — configura o ambiente de desenvolvimento
# ============================================================

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[bootstrap]${RESET} $*"; }
success() { echo -e "${GREEN}[ok]${RESET}       $*"; }
warn()    { echo -e "${YELLOW}[warn]${RESET}     $*"; }
error()   { echo -e "${RED}[error]${RESET}    $*"; exit 1; }
header()  { echo -e "\n${MAGENTA}==> $*${RESET}"; }

# ------------------------------------------------------------
# Carrega helpers
# ------------------------------------------------------------
source "$DOTFILES_DIR/lib/platform.sh"
detect_platform

info "Platform: $PLATFORM | Package manager: $PKG_MANAGER"

# ------------------------------------------------------------
# Instala módulos em ordem
# ------------------------------------------------------------
_run_install() {
  header "Installing development tools"

  mkdir -p "$HOME/Dev/tools/python/pyenv" \
           "$HOME/Dev/tools/python/poetry" \
           "$HOME/Dev/tools/node/nvm" \
           "$HOME/Dev/tools/java/sdkman" \
           "$HOME/Dev/tools/ai/claude" \
           "$HOME/Dev/tools/ai/gemini" \
           "$HOME/Dev/tools/ai/gemini-config" \
           "$HOME/Dev/repos"

  for module in  "$DOTFILES_DIR/install/00_packages.sh" \
                 "$DOTFILES_DIR/install/01_shell.sh" \
                 "$DOTFILES_DIR/install/02_chezmoi.sh" \
                 "$DOTFILES_DIR/install/03_python.sh" \
                 "$DOTFILES_DIR/install/04_java.sh" \
                 "$DOTFILES_DIR/install/05_node.sh" \
                 "$DOTFILES_DIR/install/06_ai.sh" \
                 "$DOTFILES_DIR/install/07_containers.sh"
  do
    if [[ -f "$module" ]]; then
      source "$module"
      "$(basename "$module" .sh | sed 's/^[0-9]*_/install_/')" || \
        warn "Module $(basename "$module") reported an issue — continuing"
    fi
  done
}

# ------------------------------------------------------------
# Entry point
# ------------------------------------------------------------
echo ""
echo -e "${MAGENTA}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${MAGENTA}║       linux-init-bootstrap — setup           ║${RESET}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════╝${RESET}"
echo ""

_run_install

echo ""
success "Bootstrap complete! Tools installed."
echo ""
info "Next step — apply dotfiles:"
info "  chezmoi init --apply git@github.com:nonatorw/chezmoi-dotfiles.git"
