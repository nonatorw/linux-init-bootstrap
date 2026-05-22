#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# lib/platform.sh
# Platform detection and package manager abstraction.
# Exports PLATFORM (wsl2|silverblue|linux|macos) and PKG_MANAGER (apt|brew|dnf).
# ─────────────────────────────────────────────────────────────────────────────

# ─────────────────────────────────────────────
# Summary: detect the current platform and package manager; export PLATFORM and PKG_MANAGER
# Outputs: exports PLATFORM and PKG_MANAGER into the environment
# ─────────────────────────────────────────────
detect_platform() {
  case "$(uname -s)" in
    Darwin)
      PLATFORM="macos"
      PKG_MANAGER="brew"
      ;;
    Linux)
      local is_wsl=false
      grep -qi microsoft /proc/version 2>/dev/null && is_wsl=true

      # Read /etc/os-release to detect distro and variant (WSL2 or native Linux)
      if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        if [[ "${VARIANT_ID:-}" == "silverblue" || "${VARIANT_ID:-}" == "kinoite" ]]; then
          PLATFORM="silverblue"
          PKG_MANAGER="brew"
        elif [[ "${ID:-}" == "ubuntu" || "${ID:-}" == "debian" || "${ID_LIKE:-}" == *"debian"* ]]; then
          [[ "$is_wsl" == "true" ]] && PLATFORM="wsl2" || PLATFORM="linux"
          PKG_MANAGER="apt"
        elif [[ "${ID:-}" == "fedora" || "${ID_LIKE:-}" == *"fedora"* ]]; then
          [[ "$is_wsl" == "true" ]] && PLATFORM="wsl2" || PLATFORM="linux"
          PKG_MANAGER="dnf"
        else
          [[ "$is_wsl" == "true" ]] && PLATFORM="wsl2" || PLATFORM="linux"
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

# ─────────────────────────────────────────────
# Summary: install one or more packages using the active package manager
# Args:    $* — package names
# ─────────────────────────────────────────────
pkg_install() {
  case "$PKG_MANAGER" in
    apt)  run_cmd "apt install" sudo apt install -y "$@" ;;
    brew) run_cmd "brew install" brew install "$@" ;;
    dnf)  run_cmd "dnf install" sudo dnf install -y "$@" ;;
    *)
      echo "[platform] Unknown package manager: $PKG_MANAGER"
      return 1
      ;;
  esac
}

# ─────────────────────────────────────────────
# Summary: test whether a command exists in PATH
# Args:    $1 — command name
# Returns: 0 if found, 1 if not
# ─────────────────────────────────────────────
has() {
  command -v "$1" >/dev/null 2>&1
}

# ─────────────────────────────────────────────
# Summary: install Homebrew if not present and activate it in the current session PATH
# ─────────────────────────────────────────────
ensure_brew() {
  if has brew; then
    return 0
  fi
  echo "[platform] Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to the current session PATH
  if [[ "$PLATFORM" == "macos" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
}
