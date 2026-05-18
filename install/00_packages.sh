#!/usr/bin/env bash
# ============================================================
# 00_packages.sh — pacotes base do sistema
# ============================================================

install_packages() {
  echo "[packages] Installing base packages..."

  # Silverblue e macOS usam Homebrew
  if [[ "$PKG_MANAGER" == "brew" ]]; then
    ensure_brew
  fi

  # Pacotes necessários para compilar o Python via pyenv
  if [[ "$PKG_MANAGER" == "apt" ]]; then
    sudo apt update -y
    pkg_install \
      build-essential curl git \
      libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev \
      libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev \
      libffi-dev liblzma-dev \
      eza bat jq unzip zip
  elif [[ "$PKG_MANAGER" == "dnf" ]]; then
    sudo dnf update -y
    pkg_install \
      gcc make patch gawk curl git \
      zlib-devel bzip2 bzip2-devel readline-devel \
      sqlite sqlite-devel openssl-devel tk-devel \
      libffi-devel xz-devel libuuid-devel gdbm-libs \
      eza bat jq unzip zip
  else
    pkg_install \
      curl git \
      openssl readline sqlite3 xz libyaml \
      eza bat jq unzip zip
  fi

  # zsh: instala e define como shell padrão apenas se necessário
  # Compara pelo nome do binário — evita falso negativo quando $SHELL e
  # command -v zsh apontam para paths distintos do mesmo executável
  local zsh_path
  zsh_path="$(command -v zsh 2>/dev/null || true)"

  if [[ -n "$zsh_path" && "$(basename "$SHELL")" == "zsh" ]]; then
    echo "[packages] zsh already installed and set as default shell — skipping"
  else
    if [[ -z "$zsh_path" ]]; then
      echo "[packages] Installing zsh..."
      pkg_install zsh
      zsh_path="$(command -v zsh)"
    fi
    echo "[packages] Setting zsh as default shell..."
    grep -qxF "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells
    if chsh -s "$zsh_path"; then
      echo "[packages] Default shell set to $zsh_path (restart terminal to apply)"
    else
      warn "chsh failed — set default shell manually: chsh -s $zsh_path"
    fi
  fi
}
