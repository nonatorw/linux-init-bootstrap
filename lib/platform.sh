#!/usr/bin/env bash
# ============================================================
# lib/platform.sh — detecção de plataforma e abstração de
# gerenciadores de pacotes
# ============================================================

# PLATFORM: wsl2 | silverblue | linux | macos
# PKG_MANAGER: apt | brew | dnf
detect_platform() {
  case "$(uname -s)" in
    Darwin)
      PLATFORM="macos"
      PKG_MANAGER="brew"
      ;;
    Linux)
      local is_wsl=false
      grep -qi microsoft /proc/version 2>/dev/null && is_wsl=true

      # Lê /etc/os-release para detectar distro e variante (WSL2 ou Linux nativo)
      if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        if [[ "${VARIANT_ID:-}" == "silverblue" || "${VARIANT_ID:-}" == "kinoite" ]]; then
          PLATFORM="silverblue"
          PKG_MANAGER="brew"
        elif [[ "${ID:-}" == "ubuntu" || "${ID:-}" == "debian" || "${ID_LIKE:-}" == *"debian"* ]]; then
          PLATFORM="${is_wsl:+wsl2}"; PLATFORM="${PLATFORM:-linux}"
          PKG_MANAGER="apt"
        elif [[ "${ID:-}" == "fedora" || "${ID_LIKE:-}" == *"fedora"* ]]; then
          PLATFORM="${is_wsl:+wsl2}"; PLATFORM="${PLATFORM:-linux}"
          PKG_MANAGER="dnf"
        else
          PLATFORM="${is_wsl:+wsl2}"; PLATFORM="${PLATFORM:-linux}"
          PKG_MANAGER="apt"
        fi
      elif $is_wsl; then
        PLATFORM="wsl2"
        PKG_MANAGER="apt"
      fi
      ;;
    *)
      PLATFORM="unknown"
      PKG_MANAGER="unknown"
      ;;
  esac

  export PLATFORM PKG_MANAGER
}

# Instala um ou mais pacotes usando o gerenciador da plataforma atual
# Uso: pkg_install curl git zsh
pkg_install() {
  case "$PKG_MANAGER" in
    apt)  sudo apt install -y "$@" ;;
    brew) brew install "$@" ;;
    dnf)  sudo dnf install -y "$@" ;;
    *)
      echo "[platform] Unknown package manager: $PKG_MANAGER"
      return 1
      ;;
  esac
}

# Verifica se um comando existe
has() {
  command -v "$1" >/dev/null 2>&1
}

# Garante que o Homebrew está instalado (Silverblue e macOS)
ensure_brew() {
  if has brew; then
    return 0
  fi
  echo "[platform] Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Adiciona brew ao PATH da sessão atual
  if [[ "$PLATFORM" == "macos" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
}
