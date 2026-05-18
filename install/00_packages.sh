#!/usr/bin/env bash
# ============================================================
# 00_packages.sh — pacotes base do sistema
# ============================================================

install_packages() {
  step_header "${_BOOTSTRAP_STEP_N}" "${_BOOTSTRAP_STEP_TOTAL}" \
    "Packages" "build-essential · zsh · eza · bat · jq · socat"

  if [[ "$PKG_MANAGER" == "brew" ]]; then
    step "Ensuring Homebrew is available..."
    ensure_brew
    ok "Homebrew ready"
  fi

  if [[ "$PKG_MANAGER" == "apt" ]]; then
    step "Updating apt package index..."
    sudo apt update -y
    step "Installing build dependencies and base tools..."
    pkg_install build-essential  \
                curl             \
                git              \
                libssl-dev       \
                zlib1g-dev       \
                libbz2-dev       \
                libreadline-dev  \
                libsqlite3-dev   \
                libncursesw5-dev \
                xz-utils         \
                tk-dev           \
                libxml2-dev      \
                libxmlsec1-dev   \
                libffi-dev       \
                liblzma-dev      \
                eza              \
                bat              \
                jq               \
                unzip            \
                zip              \
                socat
  elif [[ "$PKG_MANAGER" == "dnf" ]]; then
    step "Upgrading system packages..."
    sudo dnf5 check-upgrade || true
    sudo dnf5 upgrade -y
    step "Installing system tool groups..."
    sudo dnf5 group install -y system-tools admin-tools
    step "Installing build dependencies and base tools..."
    pkg_install gcc             \
                make            \
                patch           \
                gawk            \
                curl            \
                git             \
                zlib-devel      \
                bzip2           \
                bzip2-devel     \
                readline-devel  \
                sqlite          \
                sqlite-devel    \
                openssl-devel   \
                tk-devel        \
                libffi-devel    \
                xz-devel        \
                libuuid-devel   \
                gdbm-libs       \
                eza             \
                bat             \
                jq              \
                unzip           \
                zip             \
                socat
  else
    step "Installing base tools via Homebrew..."
    pkg_install curl            \
                git             \
                openssl         \
                readline        \
                sqlite3         \
                xz              \
                libyaml         \
                eza             \
                bat             \
                jq              \
                unzip           \
                zip             \
                socat
  fi
  ok "Base packages installed"

  # Locale: ensure en_US.UTF-8 is generated — required by .zshrc which exports LC_ALL=en_US.UTF-8
  if [[ "$PKG_MANAGER" == "apt" ]]; then
    if locale -a 2>/dev/null | grep -q "en_US.utf8"; then
      skip "locale en_US.UTF-8"
    else
      step "Generating locale en_US.UTF-8..."
      sudo locale-gen en_US.UTF-8
      sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
      ok "Locale en_US.UTF-8 generated"
    fi
  fi

  # zsh: install and set as default shell only if needed.
  # Compare by binary name — avoids false negative when $SHELL and
  # command -v zsh point to different paths for the same executable.
  local zsh_path
  zsh_path="$(command -v zsh 2>/dev/null || true)"

  if [[ -n "$zsh_path" && "$(basename "$SHELL")" == "zsh" ]]; then
    skip "$(zsh --version)"
  else
    if [[ -z "$zsh_path" ]]; then
      step "Installing zsh..."
      pkg_install zsh
      zsh_path="$(command -v zsh)"
      ok "zsh installed: $(zsh --version)"
    fi
    step "Setting zsh as default shell..."
    grep -qxF "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells
    if chsh -s "$zsh_path"; then
      ok "Default shell set to $zsh_path ${DIM}(restart terminal to apply)${RESET}"
    else
      warn "chsh failed — set default shell manually: chsh -s $zsh_path"
    fi
  fi
}
