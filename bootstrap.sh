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

  mkdir -p "$HOME/Dev/tools/python/pyenv"     \
           "$HOME/Dev/tools/python/poetry"    \
           "$HOME/Dev/tools/node/nvm"         \
           "$HOME/Dev/tools/java/sdkman"      \
           "$HOME/Dev/tools/ai/claude"        \
           "$HOME/Dev/tools/ai/gemini"        \
           "$HOME/Dev/tools/ai/gemini-config" \
           "$HOME/Dev/repos"

  # ~/.ssh com permissões correctas — sem chaves locais, tudo via 1Password
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  for module in  "$DOTFILES_DIR/install/00_packages.sh"   \
                 "$DOTFILES_DIR/install/01_shell.sh"      \
                 "$DOTFILES_DIR/install/02_chezmoi.sh"    \
                 "$DOTFILES_DIR/install/03_python.sh"     \
                 "$DOTFILES_DIR/install/04_java.sh"       \
                 "$DOTFILES_DIR/install/05_node.sh"       \
                 "$DOTFILES_DIR/install/06_ai.sh"         \
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

# WSL2: verificar pré-requisito do 1Password SSH agent (npiperelay)
if [[ "$PLATFORM" == "wsl2" ]]; then
  echo ""
  header "1Password SSH Agent (WSL2)"
  _NPIPERELAY_PATH="/mnt/c/Users/${USER}/AppData/Local/Microsoft/WinGet/Links/npiperelay.exe"
  # Tenta path alternativo com username Windows diferente do Linux
  if [[ ! -x "$_NPIPERELAY_PATH" ]]; then
    _NPIPERELAY_PATH="$(find /mnt/c/Users/*/AppData/Local/Microsoft/WinGet/Links/npiperelay.exe 2>/dev/null | head -1)"
  fi
  if [[ -x "$_NPIPERELAY_PATH" ]]; then
    success "npiperelay found: $_NPIPERELAY_PATH"
    info "SSH agent relay will start automatically via dev_configs.sh"
  else
    warn "npiperelay.exe not found — 1Password SSH agent will not work in WSL2"
    warn "Install it on Windows: winget install jstarks.npiperelay"
    warn "Then ensure 1Password Developer settings have 'Use SSH agent' enabled"
    warn "See README.md for full setup instructions"
  fi
  unset _NPIPERELAY_PATH
fi

echo ""
info "Next step — apply dotfiles:"
info "  git clone https://github.com/nonatorw/chezmoi-dotfiles.git ~/Dev/repos/chezmoi-dotfiles"
info "  mkdir -p ~/.config/chezmoi"
info "  echo 'sourceDir = \"~/Dev/repos/chezmoi-dotfiles\"' > ~/.config/chezmoi/chezmoi.toml"
info "  chezmoi apply"
